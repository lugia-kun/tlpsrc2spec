require "spec"
require "../src/tlpsrc2spec"
require "../src/rule"

DATA_DIR = File.join(File.dirname(__FILE__), "data")

def fixture(path)
  File.join(DATA_DIR, path)
end
