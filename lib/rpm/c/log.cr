
module RPM
  lib LibRPM
    RPMLOG_PREMASK = 0x07

    enum LogLvl
      EMERG = 0
      ALERT = 1
      CRIT = 2
      ERR = 3
      WARNING = 4
      NOTICE = 5
      INFO = 6
      DEBUG = 7
    end

    fun rpmlogSetMask(LibC::Int) : LibC::Int
    fun rpmlogMessage() : UInt8*
  end
end
