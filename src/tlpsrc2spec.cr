require "rpm"
require "./tlpdb"

# TODO: Write documentation for `Tlpsrc2spec`
module TLpsrc2spec
  VERSION = "0.1.0"

  DEFAULT_RPM_CATEGORY = "Application/Publishing"

  class FileAttribute
    property mode : UInt32
    property user : String?
    property group : String?

    def initialize(@mode = 0o0777, @user = nil, @group = nil)
    end
  end

  class FileEntry
    property path : String
    property attr : FileAttribute?
    property verity : String?
    property? doc : Bool
    property? docdir : Bool
    property? dir : Bool

    def initialize(@path, @attr = nil, @verity = nil, @doc = false,
                   @docdir = false, @dir = false)
    end
  end

  class Package
    property name : String
    property description : String?
    property category : String
    property summary : String?
    property requires : Array(String)
    property version : String?
    property release : String?
    property files : Array(FileEntry)
    property post : String?
    property postun : String?
    property pre : String?
    property preun : String?
    property pretrans : String?
    property posttrans : String?
    property tlpdb_pkgs : Array(TLPDB::Package)
    property? full_named_package : Bool

    def initialize(@name, @description = nil, @category = DEFAULT_RPM_CATEGORY,
                   @summary = nil, @requires = ([] of String), @version = nil,
                   @release = nil, @files = ([] of FileEntry), @post = nil,
                   @postun = nil, @preun = nil, @pretrans = nil,
                   @posttrans = nil, @tlpdb_pkgs = ([] of TLPDB::Package),
                   @full_named_package = false)
    end
  end

  def self.main(argv = ARGV)
  end
end

TLpsrc2spec.main
