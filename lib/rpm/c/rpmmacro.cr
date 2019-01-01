
require "rpm/c/types"

module RPM
  lib LibRPM
    $macrofiles : UInt8*

   	RMIL_DEFAULT = -15
 	RMIL_MACROFILES = -13
    RMIL_RPMRC = -11
    RMIL_CMDLINE = -7
    RMIL_TARBALL = -5
    RMIL_SPEC = -3
    RMIL_OLDSPEC = -1
    RMIL_GLOBAL = 0

    {% if compare_versions(`pkg-config --modversion rpm`, "4.14.0") >= 0 %}
      fun rpmPushMacro(MacroContext*, UInt8*, UInt8*, UInt8*, LibC::Int)
      fun rpmPopMacro(MacroContext*, UInt8*)
    {% else %}
      fun addMacro(MacroContext*, UInt8*, UInt8*, UInt8*, LibC::Int)
      fun delMacro(MacroContext*, UInt8*)
    {% end %}
  end
end
