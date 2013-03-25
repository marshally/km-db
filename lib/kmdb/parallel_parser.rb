require 'kmdb/parser'
require 'parallel'

module KMDB
  class ParallelParser < Parser

    def initialize(options = {})
      super(options)
      @worker_count = options.delete(:workers) || Parallel.processor_count
    end

    def run(argv)
      @pipe_rd, @pipe_wr = IO.pipe

      inputs = list_files_in(argv)
      total_bytes = total_size_of_files(inputs)
      log "total bytes : #{total_bytes}"
      total_bytes -= inputs.map { |p| Dumpfile.get(p, @resume_job) }.compact.map(&:offset).sum
      log "left to process : #{total_bytes}"

      # Start workers
      log "Using #{@worker_count} workers."
      Process.fork do
        @pipe_rd.close
        Parallel.each(inputs, :in_processes => @worker_count) do |input|
          KMDB::Event.connection.reconnect!
          log "Worker #{Process.pid} starting #{input}"
          $0 = "worker: #{input}"
          process_events_in_file(input)
          log "Worker #{Process.pid} done"
          true
        end
      end

      # Start gatherer
      $0 = "gatherer: #{$0}"
      @pipe_wr.close
      byte_counter = 0
      log "Starting gatherer, total bytes: #{total_bytes}"
      progress = ProgressBar.new("-" * 20, total_bytes)
      while line = @pipe_rd.gets
        if line =~ /^OK (\d+)$/
          byte_counter += $1.to_i
          progress.set byte_counter
        elsif line =~ /^FILE (.*)$/
          progress.title = $1
        else
          log "Unparsed line: '#{line}'"
        end
      end
      progress.finish
      log "Total bytes processed: #{byte_counter}"
      Process.waitall
    end

  private

    def process_events_in_file(pathname)
      pathname.open do |input|
        processed_bytes = 0
        if @resume_job
          dumpfile = Dumpfile.get(pathname, @resume_job)
          log "Starting file #{pathname} from offset #{dumpfile.offset}"
          input.seek(dumpfile.offset)
        end
        line_number = 0
        @pipe_wr.write "FILE #{pathname.basename}\n"
        while line = input.gets
          line_number += 1
          processed_bytes += line.size

          process_event(line)
          dumpfile.set(input.tell)

          if processed_bytes > 100_000
            @pipe_wr.write "OK #{processed_bytes}\n"
            processed_bytes = 0
          end
        end
        @pipe_wr.write "OK #{processed_bytes}\n"
      end
    end

  end
end
