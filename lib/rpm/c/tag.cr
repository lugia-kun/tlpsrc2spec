require "rpm/c/types"

module RPM
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
    Packages = 0
    Label = 2
    Name = Tag::Name
    BaseNames = Tag::BaseNames
    Group = Tag::Group
    RequireName = Tag::RequireName
    ProvideName = Tag::ProvideName
    ConflictName = Tag::ConflictName
    ObsoleteName = Tag::ObsoleteName
    TriggerName = Tag::TriggerName
    DirNames = Tag::DirNames
    InstallTid = Tag::InstallTid

    SigMD5 = Tag::SigMD5
    SHA1Header = Tag::SHA1Header
    InstFileNames = Tag::InstFileNames
    FileTriggerName = Tag::FileTriggerName

    TransFileTriggerName = Tag::TransfileTriggerName
    RecommendName = Tag::RecommendName
    SuggestNmae = Tag::SuggestName
    SupplementName = Tag::SupplementName

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

  lib LibRPM
    fun rpmTagGetName(TagVal) : UInt8*
    fun rpmTagGetNames(TagData, LibC::Int) : LibC::Int
    fun rpmTagGetClass(TagVal) : TagClass
    fun rpmTagGetType(TagVal) : RPMFlags
  end

  {% if compare_versions(`pkg-config rpm --modversion`, "4.9.0") >= 0 %}
    lib LibRPM
      fun rpmTagType(TagVal) : TagType
      fun rpmTagGetReturnType(TagVal) : TagReturnType
    end
    def self.rpmTagType(v) : TagType
      LibRPM.rpmTagType(v)
    end
    def self.rpmTagGetreturnType(v) : TagReturnType
      LibRPM.rpmTagGetReturnType(v)
    end
  {% else %}
    def self.rpmTagType(v) : TagType
      m = LibRPM.rpmTagGetType(v)
      TagType.new((m & ~TagReturnType::MASK.value).to_i32)
    end
    def self.rpmTagGetReturnType(v) : TagReturnType
      m = LibRPM.rpmTagGetType(v)
      TagReturnType.new(m & TagReturnType::MASK.value)
    end
  {% end %}
end
