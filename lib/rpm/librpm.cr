module RPM
  @[Link(ldflags: "`pkg-config rpm --libs`")]
  lib LibRPM
    # ## Internal types
    alias Count = UInt32
    alias RPMFlags = UInt32
    alias TagVal = Int32
    alias DbiTagVal = TagVal
    alias Loff = UInt64

    alias Int = LibC::Int
    alias UInt = LibC::UInt
    alias SizeT = LibC::SizeT

    type Header = Pointer(Void)
    type HeaderIterator = Pointer(Void)
    type Transaction = Pointer(Void)
    type Database = Pointer(Void)
    type DatabaseMatchIterator = Pointer(Void)
    type MacroContext = Pointer(Void)
    type Problem = Pointer(Void)
    type FnpyKey = Pointer(Void)
    type DependencySet = Pointer(Void)
    type ProblemSet = Pointer(Void)
    type ProblemSetIterator = Pointer(Void)
    type TagData = Pointer(Void)
    type Relocation = Pointer(Void)
    type FD = Pointer(Void)

    alias RPMDs = DependencySet
    alias RPMPs = ProblemSet
    alias RPMPsi = ProblemSetIterator
    alias RPMTd = TagData
    alias RPMTs = Transaction
    alias RPMDb = Database
    alias RPMDbMatchIterator = DatabaseMatchIterator

    enum RC
      OK, NOTFOUND, FAIL, NOTTRUSTED, NOKEY
    end

    # ## Callback APIs.
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

    alias CallbackData = Pointer(Void)
    type CallbackFunction = (Void*, CallbackType, Loff, Loff, CallbackData) -> Pointer(Void)

    # ## CLI APIs.
    fun rpmShowProgress(Void*, CallbackType, Loff, Loff, FnpyKey, Void*) : Pointer(Void)

    # ## DB APIs.
    enum MireMode
      DEFAULT = 0
      STRCMP  = 1
      REGEX   = 2
      GLOB    = 3
    end

    fun rpmdbCountPackages(RPMDb, UInt8*) : Int
    fun rpmdbGetIteratorOffset(RPMDbMatchIterator) : UInt
    fun rpmdbGetIteratorCount(RPMDbMatchIterator) : Int
    fun rpmdbSetIteratorRE(RPMDbMatchIterator, TagVal, MireMode, UInt8*) : Int

    fun rpmdbInitIterator(RPMDbMatchIterator, DbiTagVal, Void*, SizeT) : RPMDbMatchIterator

    fun rpmdbNextIterator(RPMDbMatchIterator) : Header
    fun rpmdbFreeIterator(RPMDbMatchIterator) : Void

    # ## Dependency Set APIs.
    @[Flags]
    enum Sense : RPMFlags
      ANY           = 0
      LESS          = (1 << 1)
      GREATER       = (1 << 2)
      EQUAL         = (1 << 3)
      POSTTRANS     = (1 << 5)
      PREREQ        = (1 << 6)
      PRETRANS      = (1 << 7)
      INTERP        = (1 << 8)
      SCRIPT_PRE    = (1 << 9)
      SCRIPT_POST   = (1 << 10)
      SCRIPT_PREUN  = (1 << 11)
      SCRIPT_POSTUN = (1 << 12)
      SCRIPT_VERIFY = (1 << 13)
      FIND_REQUIRES = (1 << 14)
      FIND_PROVIDES = (1 << 15)
      TRIGGERIN     = (1 << 16)
      TRIGGERUN     = (1 << 17)
      TRIGGERPOSTUN = (1 << 18)
      MISSINGOK     = (1 << 19)
      RPMLIB        = (1 << 24)
      TRIGGERPREIN  = (1 << 25)
      KEYRING       = (1 << 26)
      CONFIG        = (1 << 28)
    end

    fun rpmdsSingle(TagVal, UInt8*, UInt8*, Sense) : RPMDs
    fun rpmdsCompare(RPMDs) : Int

    # ## File Info Set APIs.
    enum FileAttrs : RPMFlags
      NONE   = 0
      CONFIG = (1 << 0)
      DOC    = (1 << 1)
      ICON   = (1 << 2)

      MISSINGOK = (1 << 3)
      NOREPLACE = (1 << 4)
      SPECFILE  = (1 << 5)
      GHOST     = (1 << 6)

      LICENSE = (1 << 7)
      README  = (1 << 8)
      PUBKEY  = (1 << 11)
    end

    enum FileState
      MISSING      = -1
      NORMAL       =  0
      REPLACED     =  1
      NOTINSTALLED =  2

      NETSHARED  = 3
      WRONGCOLOR = 4
    end

    # ## Tag APIs.
    enum Tag : TagVal
      NotFound         =  -1
      HeaderImage      =  61
      HeaderSignatures =  62
      HeaderImmutable  =  63
      HeaderRegions    =  64
      HeaderI18nTable  = 100

      SigBase         = 256
      SigSize
      SigLEMD5_1
      SigPGP
      SigLEMD5_2
      SigMD5
      SigGPG
      SigPGP5
      BadSHA1_1
      BadSHA1_2
      Pubkeys
      DSAHeader
      RSAHeader
      SHA1Header
      LongSigSize
      LongArchiveSize
      SHA256Header    = SigBase + 17

      Name                        = 1000
      Version
      Release
      Epoch
      Summary
      Description
      BuildTime
      BuildHost
      InstallTime
      Size
      Distribution
      Vendor
      GIF
      XPM
      License
      Packager
      Group
      ChangeLog
      Source
      Patch
      URL
      OS
      Arch
      PreIn
      PostIn
      PreUn
      PostUn
      OldFilenames
      FileSizes
      FileStates
      FileModes
      FileUIDs
      FileGIDs
      FileRDEVs
      FileMTimes
      FileDigests
      FileLinkTos
      FileFlags
      Root
      FileUserName
      FileGroupName
      Exclude
      Exclusive
      Icon
      SourceRPM
      FileVerifyFlags
      ArchiveSize
      ProvideName
      RequireFlags
      RequireName
      RequireVersion
      NoSource
      NoPatch
      ConflictFlags
      ConflictName
      ConflictVersion
      DefaultPrefix
      BuildRoot
      InstallPrefix
      ExcludeArch
      ExcludeOS
      ExclusiveArch
      ExclusiveOS
      AutoReqProv
      RPMVersion
      TriggerScripts
      TriggerName
      TriggerVersion
      TriggerFlags
      TriggerIndex
      VerifyScript                = 1079
      ChangeLogTime
      ChangeLogName
      ChangeLogText
      BrokenMD5
      PreReq
      PreInProg
      PostInProg
      PreUnProg
      PostUnProg
      BuildArchs
      ObsoleteName
      VerifyScriptProg
      TriggerScriptProg
      DocDir
      Cookie
      FileDevices
      FileInodes
      FileLangs
      Prefixes
      InstPrefixes
      TriggerIn
      TriggerUn
      TriggerPostUn
      AutoReq
      AutoProv
      Capability
      SourcePackage
      OldOrigFileNames
      BuildPreReq
      BuildRequires
      BuildConflicts
      BuildMacros
      ProvideFlags
      ProvideVersion
      ObsoleteFlags
      ObsoleteVersion
      DirIndexes
      BaseNames
      DirNames
      OrigDirIndexes
      OrigBaseNames
      OrigDirNames
      OptFlags
      DistURL
      PayloadFormat
      PayloadCompressor
      PayloadFlags
      InstallColor
      InstallTid
      RemoveTid
      SHA1RHN
      RHNPlatform
      Platform
      PatchesName
      PatchesFlags
      PatchesVersion
      CacheCTime
      CachePkgPath
      CachePkgSize
      CachePkgMTime
      FileColors
      FileClass
      ClassDict
      FileDependsX
      FileDependsN
      DependsDict
      SourcePkgID
      FileContexts
      FSContexts
      Recontexts
      Policies
      PreTrans
      PostTrans
      PreTransProg
      PostTransProg
      DistTag
      OldSuggestsName
      OldSuggestsVersion
      OldSuggestsFlags
      OldEnhancesName
      OldEnhancesVersion
      OldEnhancesFlags
      Priority
      CVSID
      BLinkPkgID
      BLinkHdrID
      BLinkNevRA
      FLinkPkgID
      FLinkHdrID
      FLinkNevRA
      PackageOrigin
      TriggerPreIn
      BuildSuggests
      BuildEnhances
      ScriptStates
      ScriptMetrics
      BuildCPUClock
      FileDigestAlgos
      Variants
      XMajor
      XMinor
      RepoTag
      Keywords
      BuildPlatforms
      PackageColor
      PackagePrefColor
      XAttrsDict
      FileXAttrsX
      DepAttrsDict
      ConflictAttrsX
      ObsoleteAttrsX
      ProvideAttrsX
      RequireAttrsX
      BuildProvides
      BuildObsoletes
      DBInstance
      NVRA
      FileNames                   = 5000
      FileProvide
      FileRequire
      FSNames
      FSSizes
      TriggerConds
      TriggerType
      OrigFileNames
      LongFileSizes
      LongSize
      FileCaps
      FileDigestAlgo
      BugURL
      EVR
      NVR
      NEVR
      NEVRA
      HeaderColor
      Verbose
      EpochNum
      PreInFlags
      PostInFlags
      PreUnFlags
      PostUnFlags
      PreTransFlags
      PostTransFlags
      VerifyScriptFlags
      TriggerScriptFlags
      Collections                 = 5029
      PolicyNames
      PolicyTypes
      PolicyTypesIndexes
      PolicyFlags
      VCS
      OrderName
      OrderVersion
      OrderFlags
      MSSFManifest
      MSSFDomain
      InstFileNames
      RequireNEVRS
      ProvideNEVRS
      ObsoleteNEVRS
      ConflictNEVRS
      FileNLinks
      RecommendName
      RecommendVersion
      RecommendFlags
      SuggestName
      SuggestVersion
      SuggestFlags
      SupplementName
      SupplementVersion
      SupplementFlags
      EnhanceName
      EnhanceVersion
      EnhanceFlags
      RecommendNEVRS
      SuggestNEVRS
      SupplementNEVRS
      EnhanceNEVRS
      Encoding
      FileTriggerIn
      FileTriggerUn
      FileTriggerPostUn
      FileTriggerScripts
      FileTriggerScriptProg
      FileTriggerScriptFlags
      FileTriggerName
      FileTriggerIndex
      FileTriggerVersion
      FileTriggerFlags
      TransfileTriggerIn
      TransfileTriggerUn
      TransfileTriggerPostUn
      TransfileTriggerScripts
      TransfileTriggerScriptProg
      TransfileTriggerScriptFlags
      TransfileTriggerName
      TransfileTriggerIndex
      TransfileTriggerVersion
      TransfileTriggerFlags
      RemovePathPostFixes
      FileTriggerPriorities
      TransfileTriggerPriorities
      FileTriggerConds
      FileTriggerType
      TransfileTriggerConds
      TransfileTriggerType
      FileSignatures
      FileSignatureLength
      PayloadDigest
      PayloadDigestAlgo

      FirstFreeTag
    end

    enum DbiTag : DbiTagVal
      Packages     = 0
      Label        = 2
      Name         = Tag::Name
      BaseNames    = Tag::BaseNames
      Group        = Tag::Group
      RequireName  = Tag::RequireName
      ProvideName  = Tag::ProvideName
      ConflictName = Tag::ConflictName
      ObsoleteName = Tag::ObsoleteName
      TriggerName  = Tag::TriggerName
      DirNames     = Tag::DirNames
      InstallTid   = Tag::InstallTid

      SigMD5          = Tag::SigMD5
      SHA1Header      = Tag::SHA1Header
      InstFileNames   = Tag::InstFileNames
      FileTriggerName = Tag::FileTriggerName

      TransFileTriggerName = Tag::TransfileTriggerName
      RecommendName        = Tag::RecommendName
      SuggestNmae          = Tag::SuggestName
      SupplementName       = Tag::SupplementName

      EnhanceName = Tag::EnhanceName
    end

    @[Flags]
    enum TagReturnType : RPMFlags
      ANY     =           0
      SCALAR  = 0x0001_0000
      ARRAY   = 0x0002_0000
      MAPPING = 0x0004_0000
      MASK    = 0xFFFF_0000
    end

    enum TagType
      NULL         = 0,
      CHAR         = 1,
      INT8         = 2,
      INT16        = 3,
      INT32        = 4,
      INT64        = 5,
      STRING       = 6,
      BIN          = 7,
      STRING_ARRAY = 8,
      I18NSTRING   = 9
    end

    enum SubTagType
      REGION    = -10
      BIN_ARRAY = -11
      XREF      = -12
    end

    enum TagClass
      NULL, NUMERIC, STRING, BINARY
    end

    fun rpmTagGetName(TagVal) : Pointer(UInt8)
    fun rpmTagGetNames(TagData, Int) : Int
    fun rpmTagGetClass(TagVal) : TagClass
    fun rpmTagGetType(TagVal) : RPMFlags

    # These two functions are added on 4.9.0
    # Use RPM#tag_type and RPM#tag_get_return_type instead.
    fun rpmTagType(TagVal) : TagType
    fun rpmTagGetReturnType(TagVal) : TagReturnType

    # ## Header APIs.
    @[Flags]
    enum HeaderGetFlags : RPMFlags
      DEFAULT = 0
      MINMEM  = (1 << 0)
      EXT     = (1 << 1)
      RAW     = (1 << 2)
      ALLOC   = (1 << 3)
      ARGV    = (1 << 4)
    end

    @[Flags]
    enum HeaderPutFlags : RPMFlags
      DEFAULT = 0
      APPEND  = (1 << 0)
    end

    enum HeaderConvOps
      EXPANDFILELIST   = 0
      COMPRESSFILELIST = 1
      RETROFIT_V3      = 2
    end

    fun headerNew : Header
    fun headerFree(Header) : Header
    fun headerLink(Header) : Header

    fun headerGet(Header, TagVal, TagData, HeaderGetFlags) : Int
    fun headerGetString(Header, TagVal) : Pointer(UInt8)
    fun headerGetAsString(Header, TagVal) : Pointer(UInt8)
    fun headerPut(Header, TagData, HeaderPutFlags) : Int
    fun headerPutString(Header, TagVal, UInt8*) : Int
    fun headerPutUint32(Header, TagVal, UInt32*, Count) : Int

    fun rpmReadPackageFile(Transaction, FD, UInt8*, Header*) : RC

    # ## IO APIs.
    fun Fopen(UInt8*, UInt8*) : FD
    fun Fclose(FD) : Void
    fun Ferror(FD) : Int
    fun fdDup(Int) : FD
    fun Fstrerror(FD) : Pointer(UInt8)
    fun fdLink(Void*) : FD

    # ## Library APIs.
    $rpmversion = RPMVERSION : Pointer(UInt8)
    $rpmEVR : Pointer(UInt8)

    fun rpmReadConficFiles(UInt8*, UInt8*) : Int
    fun rpmvercomp(UInt8*, UInt8*) : Int

    # ## Log APIs.
    RPMLOG_PREMASK = 0x07

    enum LogLvl
      EMERG   = 0
      ALERT   = 1
      CRIT    = 2
      ERR     = 3
      WARNING = 4
      NOTICE  = 5
      INFO    = 6
      DEBUG   = 7
    end

    fun rpmlogSetMask(Int) : Int
    fun rpmlogMessage : Pointer(UInt8)

    # ## Macro APIs.
    $macrofiles : Pointer(UInt8)

    RMIL_DEFAULT    = -15
    RMIL_MACROFILES = -13
    RMIL_RPMRC      = -11
    RMIL_CMDLINE    =  -7
    RMIL_TARBALL    =  -5
    RMIL_SPEC       =  -3
    RMIL_OLDSPEC    =  -1
    RMIL_GLOBAL     =   0

    # Use RPM#push_macro and RPM#pop_macro

    # These two functions are added at 4.14.0
    fun rpmPushMacro(MacroContext, UInt8*, UInt8*, UInt8*, Int) : Int
    fun rpmPopMacro(MacroContext, UInt8*) : Int

    # These two functions are removed at 4.14.0
    fun addMacro(MacroContext, UInt8*, UInt8*, UInt8*, Int) : Int
    fun delMacro(MacroContext, UInt8*) : Int

    # ## Problem APIs.
    @[Flags]
    enum ProbFilterFlags : RPMFlags
      NONE            = 0
      IGNOREOS        = (1 << 0)
      IGNOREARCH      = (1 << 1)
      REPLACEPKG      = (1 << 2)
      FORCERELOCATE   = (1 << 3)
      REPLACENEWFILES = (1 << 4)
      REPLACEOLDFILES = (1 << 5)
      OLDPACKAGE      = (1 << 6)
      DISKSPACE       = (1 << 7)
      DISKNODES       = (1 << 8)
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
    fun rpmProblemGetStr(Problem) : Pointer(UInt8)
    fun rpmProblemString(Problem) : Pointer(UInt8)
    fun rpmProblemCompare(Problem, Problem) : Int

    # ## Problem Set APIs.
    fun rpmpsInitIterator(ProblemSet) : ProblemSetIterator
    fun rpmpsNextIterator(ProblemSetIterator) : Int
    fun rpmpsGetProblem(ProblemSetIterator) : Problem
    fun rpmpsFree(ProblemSet) : ProblemSet

    # ## TagData APIs.
    fun rpmtdNew : TagData
    fun rpmtdFree(TagData) : TagData
    fun rpmtdReset(TagData) : TagData
    fun rpmtdFreeData(TagData) : Void
    fun rpmtdCount(TagData) : UInt32
    fun rpmtdTag(TagData) : TagVal
    fun rpmtdType(TagData) : TagType

    fun rpmtdInit(TagData) : LibC::Int
    fun rpmtdNext(TagData) : LibC::Int
    fun rpmtdNextUint32(TagData) : Pointer(UInt32)
    fun rpmtdNextUint64(TagData) : Pointer(UInt64)
    fun rpmtdNextString(TagData) : Pointer(UInt8)
    fun rpmtdGetChar(TagData) : Pointer(UInt8)
    fun rpmtdGetUint16(TagData) : Pointer(UInt16)
    fun rpmtdGetUint32(TagData) : Pointer(UInt32)
    fun rpmtdGetUint64(TagData) : Pointer(UInt64)
    fun rpmtdGetString(TagData) : Pointer(UInt8)
    fun rpmtdGetNumber(TagData) : UInt64

    fun rpmtdFromUint8(TagData, TagVal, UInt8*, Count) : Int
    fun rpmtdFromUint16(TagData, TagVal, UInt16*, Count) : Int
    fun rpmtdFromUint32(TagData, TagVal, UInt32*, Count) : Int
    fun rpmtdFromUint64(TagData, TagVal, UInt64*, Count) : Int
    fun rpmtdFromString(TagData, TagVal, UInt8*) : Int
    fun rpmtdFromStringArray(TagData, TagVal, UInt8**, Count) : Int

    # ## Transaction APIs.
    @[Flags]
    enum TransFlags : RPMFlags
      NONE            = 0
      TEST            = (1 << 0)
      BUILD_PROBS     = (1 << 1)
      NOSCRIPTS       = (1 << 2)
      JUSTDB          = (1 << 3)
      NOTRIGGERS      = (1 << 4)
      NODOCS          = (1 << 5)
      ALLFILES        = (1 << 6)
      NOPLUGINS       = (1 << 7)
      NOCONTEXTS      = (1 << 8)
      NOCAPS          = (1 << 9)
      NOTRIGGERPREIN  = (1 << 16)
      NOPRE           = (1 << 17)
      NOPOST          = (1 << 18)
      NOTRIGGERIN     = (1 << 19)
      NOTRIGGERUN     = (1 << 20)
      NOPREUN         = (1 << 21)
      NOPOSTUN        = (1 << 22)
      NOTRIGGERPOSTUN = (1 << 23)
      NOPRETRANS      = (1 << 24)
      NOPOSTTRANS     = (1 << 25)
      NOMD5           = (1 << 27)
      NOFILEDIGEST    = (1 << 27)
      NOCONFIGS       = (1 << 30)
      DEPLOOPS        = (1 << 31)
    end

    fun rpmtsCheck(Transaction) : Int
    fun rpmtsOrder(Transaction) : Int
    fun rpmtsRun(Transaction, ProblemSet, ProbFilterFlags) : Int
    fun rpmtsLink(Transaction) : Transaction
    fun rpmtsCloseDB(Transaction) : Int
    fun rpmtsOpenDB(Transaction, Int) : Int
    fun rpmtsInitDB(Transaction, Int) : Int
    fun rpmtsGetDBMode(Transaction) : Int
    fun rpmtsSetDBMode(Transaction, Int) : Int
    fun rpmtsRebuildDB(Transaction)
    fun rpmtsVerifyDB(Transaction)
    fun rpmtsInitIterator(Transaction, DbiTagVal, Void*, SizeT) : DatabaseMatchIterator
    fun rpmtsProblems(Transaction) : ProblemSet

    fun rpmtsClean(Transaction) : Void
    fun rpmtsFree(Transaction) : Transaction

    fun rpmtsSetNotifyCallback(Transaction, CallbackFunction, Relocation) : Int

    fun rpmtsRootDir(Transaction) : Pointer(UInt8)
    fun rpmtsSetRootDir(Transaction, UInt8*) : Int

    fun rpmtsGetRdb(Transaction) : Database

    fun rpmtsFlags(Transaction) : TransFlags
    fun rpmtsSetFlags(Transaction, TransFlags) : TransFlags

    fun rpmtsCreate : Transaction
    fun rpmtsAddInstallElement(Transaction, Header, FnpyKey, Int, Relocation) : Int
    fun rpmtsAddEraseElement(Transaction, Header, Int) : Int
  end # LibRPM

  # Exposed Types
  alias TagValue = LibRPM::TagVal
  alias DbiTagValue = LibRPM::DbiTagVal
  alias Tag = LibRPM::Tag
  alias DbiTag = LibRPM::DbiTag
  alias TagType = LibRPM::TagType
  alias TagReturnType = LibRPM::TagReturnType
  alias FileState = LibRPM::FileState

  macro _version_depends(version)
    PKGVERSION = version

    {% if compare_versions(version, "4.9.0") >= 0 %}
      def self.tag_type(v) : TagType
        LibRPM.rpmTagType(v)
      end

      def self.tag_get_return_type(v) : TagReturnType
        LibRPM.rpmTagGetReturnType(v)
      end
    {% else %}
      def self.tag_type(v) : TagType
        m = LibRPM.rpmTagGetType(v)
        TagType.new((m & ~TagReturnType::MASK.value).to_i32)
      end

      def self.tag_get_return_type(v) : TagReturnType
        m = LibRPM.rpmTagGetType(v)
        TagReturnType.new(m & TagReturnType::MASK.value)
      end
    {% end %}

    {% if compare_versions(version, "4.14.0") >= 0 %}
      def push_macro(mc, n, o, b, level) : Int
        LibRPM.rpmPushMacro(mc, n, o, b, level)
      end

      def pop_macro(mc, n) : Int
        LibRPM.rpmPopMacro(mc, n)
      end
    {% else %}
      def push_macro(mc, n, o, b, level) : Int
        LibRPM.addMacro(mc, n, o, b, level)
      end

      def pop_macro(mc, n) : Int
        LibRPM.delMacro(mc, n)
      end
    {% end %}
  end

  # `pkg-config rpm --modversion` can be 4-parted version, like "4.14.0.2"
  _version_depends({{`pkg-config rpm --modversion`.split(".")[0..2].join(".").chomp}})
end
