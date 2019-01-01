require "rpm/c/types"
require "rpm/c/callback"

module RPM
  lib LibRPM
    fun rpmShowProgress(Void*, CallbackType, Loff, Loff, Void*, Void*) : Void*
  end
end
