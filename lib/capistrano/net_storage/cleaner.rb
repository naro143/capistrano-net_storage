require 'capistrano/net_storage/utils'

module Capistrano
  module NetStorage
    # Executor class for cleaning tasks
    class Cleaner
      include Capistrano::NetStorage::Utils

      # Clean up old release directories on local.
      # Assumes they are under +config.local_releases_path+
      # @see Capistrano::NetStorage::Config#local_releases_path
      def cleanup_local_releases
        c = config
        run_locally do
          contents = capture(:ls, '-x', c.local_releases_path).split
          # reference
          # https://github.com/capistrano/capistrano/blob/cc4f31fdfcb4a21c569422a95868d0bb52844c75/lib/capistrano/tasks/deploy.rake#L152
          releases, invalid = contents.partition { |e| /^\d{14}$/ =~ e }

          if invalid.any?
            warn "Invalid contents in #{c.local_releases_path} on local:\n#{invalid.join("\n")}"
          end

          if releases.count > fetch(:keep_releases)
            info "Keeping #{fetch(:keep_releases)} of #{releases.count} releases on local"
            old_releases = (releases - releases.last(fetch(:keep_releases))).map do |release|
              c.local_releases_path.join(release).to_s
            end
            execute :rm, '-rf', *old_releases
          else
            info "No old releases (keeping newest #{fetch(:keep_releases)}) in #{c.local_releases_path} on local"
          end
        end
      end

      # Clean up old archive files on local.
      # Assumes they are under +config.local_archives_path+
      # @see Capistrano::NetStorage::Config#local_archives_path
      def cleanup_local_archives
        c = config
        run_locally do
          contents = capture(:ls, '-x', c.local_archives_path).split
          archives, invalid = contents.partition { |e| /^\d{14}\.#{Regexp.escape(c.archive_suffix)}$/ =~ e }

          if invalid.any?
            warn "Invalid contents in #{c.local_archives_path} on local:\n#{invalid.join("\n")}"
          end

          if archives.count > fetch(:keep_releases)
            info "Keeping #{fetch(:keep_releases)} of #{archives.count} archives on local"
            old_archives = (archives - archives.last(fetch(:keep_releases))).map do |archive|
              c.local_archives_path.join(archive).to_s
            end
            execute :rm, '-f', *old_archives
          else
            info "No old archives (keeping newest #{fetch(:keep_releases)}) in #{c.local_archives_path} on local"
          end
        end
      end

      # Clean up old archive files on remote servers.
      # Assumes they are under +config.archives_path+
      # @see Capistrano::NetStorage::Config#archives_path
      def cleanup_archives
        c = config
        on c.servers, in: :groups, limit: c.max_parallels do |host|
          contents = capture(:ls, '-x', c.archives_path).split
          archives, invalid = contents.partition { |e| /^\d{14}\.#{Regexp.escape(c.archive_suffix)}$/ =~ e }

          if invalid.any?
            warn "Invalid contents in #{c.archives_path} on #{host}:\n#{invalid.join("\n")}"
          end

          if archives.count > fetch(:keep_releases)
            info "Keeping #{fetch(:keep_releases)} of #{archives.count} archives on #{host}"
            old_archives = (archives - archives.last(fetch(:keep_releases))).map do |archive|
              c.archives_path.join(archive).to_s
            end

            if test("[ -d #{current_path} ]")
              current_release = capture(:readlink, current_path).to_s
              current_release_archive = c.archives_path.join("#{File.basename(current_release)}.#{c.archive_suffix}")
              if old_archives.include?(current_release_archive)
                warn "Current release archive was marked for being removed but it's going to be skipped on #{host}"
                old_archives.delete(current_release_archive)
              end
            else
              debug "There is no current release present on #{host}"
            end

            if old_archives.any?
              old_archives.each_slice(100) do |old_archives_batch|
                execute :rm, '-f', *old_archives_batch
              end
            end
          else
            info "No old archives (keeping newest #{fetch(:keep_releases)}) in #{c.archives_path} on #{host}"
          end
        end
      end
    end
  end
end
