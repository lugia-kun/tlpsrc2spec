require "./tlpsrc2spec"
require "./momonga"

begin
  TLpsrc2spec.main(TLpsrc2spec::MomongaRule)
rescue e : Errno | TLpsrc2spec::TLPDB::ParseError
  STDERR.puts "#{PROGRAM_NAME}: error: #{e.to_s}".colorize(:red)
end
