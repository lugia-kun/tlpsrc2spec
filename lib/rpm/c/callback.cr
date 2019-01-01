require "rpm/c/types"

module RPM
  @[Flags]
  enum CallbackType : RPMFlags
    UNKNOWN            = 0
    INST_PROGRESS      = (1 << 0)
    INST_START         = (1 << 1)
    INST_OPEN_FILE     = (1 << 2)
    INST_CLOSE_FILE    = (1 << 3)
    TRANS_PROGRESS     = (1 << 4)
    TRANS_START        = (1 << 5)
    TRANS_STOP         = (1 << 6)
    UNINST_PROGRESS    = (1 << 7)
    UNINST_START       = (1 << 8)
    UNINST_STOP        = (1 << 9)
    REPACKAGE_PROGRESS = (1 << 10)
    REPACKAGE_START    = (1 << 11)
    REPACKAGE_STOP     = (1 << 12)
    UNPACK_ERROR       = (1 << 13)
    CPIO_ERROR         = (1 << 14)
    SCRIPT_ERROR       = (1 << 15)
  end

  lib LibRPM
    type CallbackData = Void*
    type CallbackFunction = (Void*, CallbackType, Loff, Loff, CallbackData) -> Void*
  end
end
