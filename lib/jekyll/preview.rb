require "jekyll/preview/version"

module Jekyll
  module Preview

    # Extend Jekyll's built-in Regenerator to only render and write files matching preview_path,
    # which we will set on-demand for each request.
    module Regenerator
      def regenerate?(document)
        if super && site.config["preview_path"]
          site.config["preview_path"] == document.url
        end
      end
    end

    # Jekyll extends WEBrick::HTTPServlet::FileHandler internally, so we can extend it again to call
    # Build with the preview_path.
    module Servlet
      def do_GET(req, res)
        build_opts = @jekyll_opts.merge("preview_path" => req.path, "quiet" => true)

        # TODO: Could probably cache the instance of Site and call #process on that instead
        Jekyll::Commands::Build.process(build_opts)
        super
      end
    end

    # Servlet isn't required/loaded until Serve#setup is called, so we need to prepend there.
    module Serve
      def setup(destination)
        super
        Jekyll::Commands::Serve::Servlet.prepend(Servlet)
      end
    end

    class Command < Jekyll::Command

      class << self
        def init_with_program(prog)
          prog.command(:preview) do |cmd|
            cmd.description "Serve your site locally with dynamic rendering"
            cmd.syntax "preview [options]"

            add_build_options(cmd)
            Jekyll::Commands::Serve.singleton_class::COMMAND_OPTIONS.each do |key, val|
              cmd.option key, *val
            end

            cmd.action do |argv, opts|
              extend_serve_command
              extend_regenerator
              register_hooks

              opts["destination"] ||= "_site_preview"

              Jekyll::Commands::Serve.process(opts)
            end
          end
        end

        def extend_serve_command
          Jekyll::Commands::Serve.singleton_class.prepend(Serve)
        end

        def extend_regenerator
          Jekyll::Regenerator.prepend(Regenerator)
        end

        def register_hooks
          Jekyll::Hooks.register [:pages, :posts, :documents], :post_write do |doc|
            puts "Previewing #{doc.url} from #{doc.relative_path}"
          end
        end
      end

    end
  end
end
