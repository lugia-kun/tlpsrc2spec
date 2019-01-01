module RPM
  alias RPMFlags = UInt32
  alias TagVal = Int32
  alias DbiTagVal = TagVal
  alias Loff = UInt64

  enum RC
    OK, NOTFOUND, FAIL, NOTTRUSTED, NOKEY
  end

  lib LibRPM
    type Header = Pointer(Void)
    type HeaderIterator = Void*
    type Transaction = Void*
    type MatchIterator = Void*
    type DependencySet = Void*
    type TagData = Void*
    type MacroContext = Void*
    type Problem = Void*
    type FnpyKey = Pointer(Void)
    alias Count = UInt32
  end
end
