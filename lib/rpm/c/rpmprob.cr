
require "rpm/c/types"

module RPM
  lib LibRPM
    enum ProbFilterFlags : RPMFlags
      NONE = 0
      IGNOREOS = (1 << 0)
      IGNOREARCH = (1 << 1)
      REPLACEPKG = (1 << 2)
      FORCERELOCATE = (1 << 3)
      REPLACENEWFILES = (1 << 4)
      REPLACEOLDFILES = (1 << 5)
      OLDPACKAGE = (1 << 6)
      DISKSPACE = (1 << 7)
      DISKNODES = (1 << 8)
    end

    enum ProblemType
      BADARCH
      BADOS
      PKG_INSTALLED
      BADRELOCATE
      REQUIRES
      CONFLICT
      NEW_FILE_CONFLICT
      FILE_CONFLICT
      OLDPACKAGE
      DISKSPACE
      DISKNODES
      OBSOLETES
    end

    fun rpmProblemCreate(ProblemType, UInt8*, FnpyKey, UInt8*, UInt8*, UInt64) : Problem
    fun rpmProblemFree(Problem) : Problem
    fun rpmProblemLink(Problem) : Problem
    fun rpmProblemGetType(Problem) : ProblemType
    fun rpmProblemGetKey(Problem) : FnpyKey
    fun rpmProblemGetStr(Problem) : UInt8*
    fun rpmProblemString(Problem) : UInt8*
    fun rpmProblemCompare(Problem, Problem) : LibC::Int
  end
end
