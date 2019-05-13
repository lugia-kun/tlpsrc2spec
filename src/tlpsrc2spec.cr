require "colorize"
require "logger"
require "option_parser"
require "rpm"
require "./tlpdb"
require "./filetree"
require "./deptree"
require "./strcase"
require "./rule"
require "./installed_database"

# TODO: Write documentation for `Tlpsrc2spec`
module TLpsrc2spec
  VERSION = "0.1.0"

  FORMATTER = Logger::Formatter.new do |severity, datetime, progname, mesg, io|
    if progname.size > 0
      io << progname << ": "
    end
    if severity >= Logger::Severity::ERROR
      color = :red
    elsif severity >= Logger::Severity::WARN
      color = :yellow
    elsif severity >= Logger::Severity::INFO
      color = :green
    end
    if color
      io << severity.to_s.downcase.colorize(color) <<
        ": ".colorize(color) << mesg.colorize(color)
    else
      io << severity.to_s.downcase << ": " << mesg
    end
  end
  LEVEL             = Logger::Severity::INFO
  DEFAULT_RPM_GROUP = "Application/Publishing"

  PREFIX         = RPM["_prefix"]
  DATADIR        = RPM["_datadir"]
  BINDIR         = RPM["_bindir"]
  LIBDIR         = RPM["_libdir"]
  INCLUDEDIR     = RPM["_includedir"]
  SHAREDSTATEDIR = RPM["_sharedstatedir"]
  LOCALSTATEDIR  = RPM["_localstatedir"]
  SYSCONFDIR     = RPM["_sysconfdir"]

  TEXMFDIR       = File.join(DATADIR, "texmf")
  TEXMFDISTDIR   = File.join(DATADIR, "texmf-dist")
  TEXMFLOCALDIR  = File.join(DATADIR, "texmf-local")
  TEXMFVARDIR    = File.join(LOCALSTATEDIR, "texmf")
  TEXMFCONFIGDIR = File.join(SYSCONFDIR, "texmf")
  TEXMF = [TEXMFDIR, TEXMFDISTDIR, TEXMFLOCALDIR, TEXMFVARDIR, TEXMFCONFIGDIR]

  OLDTEXMFDIR       = `kpsewhich -var-value TEXMFMAIN`.chomp
  OLDTEXMFDISTDIR   = `kpsewhich -var-value TEXMFDIST`.chomp
  OLDTEXMFVARDIR    = `kpsewhich -var-value TEXMFSYSVAR`.chomp
  OLDTEXMFCONFIGDIR = `kpsewhich -var-value TEXMFSYSCONFIG`.chomp

  @[Flags]
  enum FileMode : UInt16
    OtherExecute = 0o0001_u16
    OtherWrite   = 0o0002_u16
    OtherRead    = 0o0004_u16
    GroupExecute = 0o0010_u16
    GroupWrite   = 0o0020_u16
    GroupRead    = 0o0040_u16
    OwnerExecute = 0o0100_u16
    OwnerWrite   = 0o0200_u16
    OwnerRead    = 0o0400_u16
    Stickey      = 0o1000_u16
    SetGUID      = 0o2000_u16
    SetUID       = 0o4000_u16
  end

  class FileAttribute
    property mode : FileMode
    property user : String?
    property group : String?
    property? config : Bool
    property? noreplace : Bool
    property? missingok : Bool

    def initialize(@mode = FileMode::None, @user = nil, @group = nil,
                   @config = false, @noreplace = false, @missingok = false)
    end
  end

  class FileEntry
    property path : String
    property attr : FileAttribute?
    property verity : String?
    property? doc : Bool
    property? docdir : Bool
    property? dir : Bool
    property tlpdb_tag : TLPDB::Tag

    def initialize(@path, @attr = nil, @verity = nil, @doc = false,
                   @docdir = false, @dir = false,
                   @tlpdb_tag = TLPDB::Tag::RUNFILES)
    end
  end

  class Package
    property name : String
    property description : String?
    property group : String
    property summary : String?
    property requires : Array(String | RPM::Package | RPM::Dependency)
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
    property obsoletes : Array(String | RPM::Package | RPM::Dependency)
    property provides : Array(String | RPM::Package | RPM::Dependency)
    property license : Array(String)
    property? archdep : Bool

    def initialize(@name, *, @description = nil, @group = DEFAULT_RPM_GROUP,
                   @summary = nil, @archdep = false,
                   @requires = ([] of String | RPM::Package | RPM::Dependency),
                   @version = nil, @license = ([] of String),
                   @release = nil, @files = ([] of FileEntry), @post = nil,
                   @postun = nil, @preun = nil, @pretrans = nil,
                   @posttrans = nil, @tlpdb_pkgs = ([] of TLPDB::Package),
                   @obsoletes = ([] of String | RPM::Package | RPM::Dependency),
                   @provides = ([] of String | RPM::Package | RPM::Dependency))
    end

    def to_rpm_package
      v = @version
      if v
        ver = RPM::Version.new(v)
      else
        ver = RPM::Version.new("1")
      end
      pkg = RPM::Package.new(@name, ver)
    end
  end

  abstract class Rule
  end

  class Application
    # Database given by `.tlpdb` file.
    getter tlpdb : TLPDB
    # Template specfile name.
    getter template : String
    # Parsed data of specfile.
    getter template_data : RPM::Spec
    # Specfile data to be used for collecting installed packages and files.
    getter installed : RPM::Spec

    # Database generated from @installed
    getter installed_db : InstalledPackageDB

    # Collected package data.
    getter pkgs : Hash(String, Package) = {} of String => Package

    def self.log
      TLpsrc2spec.log
    end

    def self.create(tlpdb_file : String, template_specfile : String,
                    installed : String, **opts)
      @@verbose = opts[:verbose]? || false
      log.info "Reading TLPDB #{tlpdb_file}..."
      tlpdb = File.open(tlpdb_file, "r") do |fp|
        TLPDB.parse(fp)
      end

      log.info "Reading Spec file #{installed}..."
      installed = RPM::Spec.open(installed)

      log.info "Reading Spec file #{template_specfile}..."
      tempfile = File.tempfile("template", ".spec")
      template_data =
        begin
          File.open(template_specfile, "r") do |fp|
            fp.each_line do |line|
              nline = line.gsub(/@@[^@]+@@/, "")
              tempfile.puts nline
            end
          end
          tempfile.flush
          RPM::Spec.open(tempfile.path)
        ensure
          tempfile.delete
        end
      self.new(tlpdb, template_specfile, template_data, installed)
    end

    def initialize(@tlpdb, @template, @template_data, @installed)
      @installed_db = InstalledPackageDB.new(@installed, log)
    end

    def log
      Application.log
    end

    def main(rule : Rule.class)
      rule_obj = rule.new(self)
      rule_obj.collect
    end
  end

  @@tlpdb_file : String? = nil
  @@template_specfile : String? = nil
  @@installed_specfile : String? = nil
  @@log : Logger = Logger.new(STDERR, LEVEL, FORMATTER)

  def self.log
    @@log
  end

  def self.main(rule : Rule.class, argv = ARGV)
    opts = OptionParser.new do |opts|
      opts.banner = "Usage: tlpsrc2spec --tlpdb=[TLPDB] --template=[Template] --installed=[current]"
      opts.on("-t", "--tlpdb=FILE", "TeX Live Package Database file") do |tlp|
        @@tlpdb_file = tlp
      end
      opts.on("-T", "--template=FILE", "Template RPM Spec file") do |spec|
        @@template_specfile = spec
      end
      opts.on("-I", "--installed=FILE", "RPM Spec file used for current installation") do |name|
        @@installed_specfile = name
      end
      opts.on("-v", "--verbose", "Be Verbose") do
        @@log.level -= 1
      end
      opts.on("-q", "--quiet", "Be Quiet") do
        @@log.level += 1
      end
    end

    opts.parse(argv)

    tlpdb = @@tlpdb_file
    spec = @@template_specfile
    base = @@installed_specfile
    if tlpdb && spec && base
      app = TLpsrc2spec::Application.create(tlpdb, spec, base)
      app.main(rule)
      0
    else
      @@log.error "TLPDB file not given" unless tlpdb
      @@log.error "Template specfile not given" unless spec
      @@log.error "Installed specfile not given" unless base
      STDERR.puts opts
      1
    end
  end
end
