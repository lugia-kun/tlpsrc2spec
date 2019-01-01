
require "rpm/c/types"

module RPM
  enum FileAttrs : RPMFlags
    NONE = 0
    CONFIG = (1 << 0)
    DOC = (1 << 1)
    ICON = (1 << 2)

    MISSINGOK = (1 << 3)
    NOREPLACE = (1 << 4)
    SPECFILE = (1 << 5)
    GHOST = (1 << 6)

    LICENSE = (1 << 7)
    README = (1 << 8)
    PUBKEY = (1 << 11)
  end

  enum FileState
    MISSING = -1
    NORMAL = 0
    REPLACED = 1
    NOTINSTALLED = 2

    NETSHARED = 3
    WRONGCOLOR = 4
  end

  lib LibRPM
    type Relocation = Void*
  end
end
