module PDK
  module Util
    module Git
      def self.git_bindir
        @git_dir ||= File.join('private', 'git', Gem.win_platform? ? 'cmd' : 'bin')
      end

      def self.git_paths
        @paths ||= begin
          paths = [File.join(PDK::Util.pdk_package_basedir, git_bindir)]

          if Gem.win_platform?
            paths << File.join(PDK::Util.pdk_package_basedir, 'private', 'git', 'mingw64', 'bin')
            paths << File.join(PDK::Util.pdk_package_basedir, 'private', 'git', 'mingw64', 'libexec', 'git-core')
            paths << File.join(PDK::Util.pdk_package_basedir, 'private', 'git', 'usr', 'bin')
          end

          paths
        end
      end

      def self.git_bin
        git_bin = Gem.win_platform? ? 'git.exe' : 'git'
        vendored_bin_path = File.join(git_bindir, git_bin)

        PDK::CLI::Exec.try_vendored_bin(vendored_bin_path, git_bin)
      end

      def self.git(*args)
        PDK::CLI::Exec.ensure_bin_present!(git_bin, 'git')

        PDK::CLI::Exec.execute(git_bin, *args)
      end

      def self.git_with_env(env, *args)
        PDK::CLI::Exec.ensure_bin_present!(git_bin, 'git')

        PDK::CLI::Exec.execute_with_env(env, git_bin, *args)
      end

      def self.repo?(maybe_repo)
        return bare_repo?(maybe_repo) if File.directory?(maybe_repo)

        remote_repo?(maybe_repo)
      end

      def self.bare_repo?(maybe_repo)
        env = { 'GIT_DIR' => maybe_repo }
        rev_parse = git_with_env(env, 'rev-parse', '--is-bare-repository')

        rev_parse[:exit_code].zero? && rev_parse[:stdout].strip == 'true'
      end

      def self.remote_repo?(maybe_repo)
        git('ls-remote', '--exit-code', maybe_repo)[:exit_code].zero?
      end

      def self.ls_remote(repo, ref)
        output = git('ls-remote', '--refs', repo, ref)

        unless output[:exit_code].zero?
          PDK.logger.error output[:stdout]
          PDK.logger.error output[:stderr]
          raise PDK::CLI::ExitWithError, _('Unable to access the template repository "%{repository}"') % {
            repository: repo,
          }
        end

        matching_refs = output[:stdout].split("\n").map { |r| r.split("\t") }
        matching_refs.find { |_sha, remote_ref| remote_ref == ref }.first
      end
    end
  end
end
