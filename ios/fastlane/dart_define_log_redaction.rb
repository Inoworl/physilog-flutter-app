require "base64"
require "json"

module DartDefineLogRedaction
  def self.protected_values(values)
    raise ArgumentError unless values.is_a?(Hash)

    values.flat_map do |key, value|
      assignment = "#{key}=#{value}"
      [value.to_s, assignment, Base64.strict_encode64(assignment)]
    end.reject(&:empty?).uniq.sort_by { |value| -value.bytesize }
  end

  def self.mask(values)
    return unless ENV["GITHUB_ACTIONS"] == "true"

    protected_values(values).each do |value|
      escaped = value.gsub("%", "%25").gsub("\r", "%0D").gsub("\n", "%0A")
      $stdout.puts("::add-mask::#{escaped}")
    end
    $stdout.flush
  end

  def self.redact_files(config_path, patterns)
    paths = patterns.flat_map { |pattern| Dir.glob(pattern) }.uniq
    raise ArgumentError if paths.any? { |path| File.symlink?(path) }

    paths.select! { |path| File.file?(path) }
    return if paths.empty?

    values = protected_values(JSON.parse(File.read(config_path)))
    return if values.empty?

    matcher = Regexp.union(values.map(&:b))
    paths.each do |path|
      File.binwrite(path, File.binread(path).gsub(matcher, "[REDACTED]"))
    end
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    raise ArgumentError if ARGV.length < 2

    DartDefineLogRedaction.redact_files(ARGV.first, ARGV.drop(1))
  rescue StandardError
    warn "Unable to redact iOS build logs; diagnostics withheld."
    exit 1
  end
end
