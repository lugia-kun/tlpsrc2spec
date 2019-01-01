module RPM
  @[Link(ldflags: "`pkg-config rpm --libs`")]
  lib LibRPM
  end
end

require "rpm/c/types"
require "rpm/c/tag"
require "rpm/c/header"
require "rpm/c/callback"
require "rpm/c/cli"
require "rpm/c/db"
require "rpm/c/ds"
require "rpm/c/fi"
require "rpm/c/io"
require "rpm/c/lib"
require "rpm/c/log"
require "rpm/c/rpmmacro"
require "rpm/c/rpmprob"

module RPM
  lib LibRPM
    fun rpmtsCreate : Transaction
    fun rpmtsSetRootDir(Transaction, UInt8*) : LibC::Int
    fun rpmtsFree(Transaction) : Void
    fun rpmtsInitIterator(Transaction, TagData, UInt8*, LibC::SizeT) : MatchIterator

    fun rpmtdNew : TagData
    fun rpmtdFree(TagData) : Void
  end
end

require "rpm/file"

module RPM
  VERSION = String.new(LibRPM.rpmversion)

  class ChangeLog
    property time : Time
    property name : String
    property text : String

    def initialize(@time, @name, @text)
    end
  end

  class Package
    getter ptr : LibRPM::Header

    def initialize(@ptr)
    end

    def initialize(filename : String)
      fd = LibRPM.Fopen(filename, "r")
      if LibRPM.Ferror(fd) != 0
        err = String.new(LibRPM.Fstrerror(fd))
        raise "#{filename}: #{err}"
      end
      hdr = uninitialized LibRPM::Header
      begin
        RPM.transaction do |ts|
          rc = LibRPM.rpmReadPackageFile(ts.ptr, fd, filename, pointerof(hdr))
        end
      ensure
        LibRPM.Fclose(fd)
      end
      initialize(hdr)
    end
  end

  class TagData
    getter ptr : LibRPM::TagData

    def initialize
      @ptr = LibRPM.rpmtdNew
    end

    def finalize
      LibRPM.rpmtdFree(@ptr)
    end
  end

  class MatchIterator
    getter ptr : LibRPM::MatchIterator

    include Enumerable(MatchIterator)

    def initialize(@ptr)
    end

    def each
    end

    def next_iterator
      pkg = LibRPM.rpmdbNextIterator(@ptr)
      if !pkg.null?
        Package.new(pkg)
      else
        nil
      end
    end

    def finalize
      LibRPM.rpmdbFreeIterator(@ptr)
    end
  end

  class Transaction
    getter ptr : LibRPM::Transaction

    def initialize(rootdir : String = "/")
      @ptr = LibRPM.rpmtsCreate
      LibRPM.rpmtsSetRootDir(@ptr, rootdir)
    end

    def finalize
      LibRPM.rpmtsFree(@ptr)
    end

    def init_iterator(tag : TagData, val : String)
      it_ptr = LibRPM.rpmtsInitIterator(@ptr, tag, val, 0)
      MatchIterator.new(it_ptr)
    end
  end

  def self.transaction(*args, &block)
    ts = Transaction.new(*args)
    begin
      yield(ts)
    ensure
      ts.finalize
    end
  end
end

t = RPM::Transaction.new
p RPM::VERSION
