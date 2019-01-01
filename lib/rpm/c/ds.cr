
require "rpm/c/types"

module RPM
  lib LibRPM
    enum Sense : RPMFlags
      ANY = 0
      LESS = (1 << 1)
      GREATER = (1 << 2)
      EQUAL = (1 << 3)
      POSTTRANS = (1 << 5)
      PREREQ = (1 << 6)
      PRETRANS = (1 << 7)
      INTERP = (1 << 8)
      SCRIPT_PRE = (1 << 9)
      SCRIPT_POST = (1 << 10)
      SCRIPT_PREUN = (1 << 11)
      SCRIPT_POSTUN = (1 << 12)
      SCRIPT_VERIFY = (1 << 13)
      FIND_REQUIRES = (1 << 14)
      FIND_PROVIDES = (1 << 15)
      TRIGGERIN = (1 << 16)
      TRIGGERUN = (1 << 17)
      TRIGGERPOSTUN = (1 << 18)
      MISSINGOK = (1 << 19)
      RPMLIB = (1 << 24)
      TRIGGERPREIN = (1 << 25)
      KEYRING = (1 << 26)
      CONFIG = (1 << 28)
    end

    fun rpmdsSingle(TagVal, UInt8*, UInt8*, Sense) : DependencySet
    fun rpmdsCompare(DependencySet, )
  end
end
