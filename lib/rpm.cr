
require "rpm/librpm"

require "rpm/file"

module RPM
  # Runtime Version of RPM Library (RPM::PKGVERSION is compile-time version)
  VERSION = String.new(LibRPM.rpmversion)
end

#
#
#   class Package
#     getter ptr : LibRPM::Header
#
#     def initialize(@ptr)
#     end
#
#     def initialize(filename : String)
#       fd = LibRPM.Fopen(filename, "r")
#       if LibRPM.Ferror(fd) != 0
#         err = String.new(LibRPM.Fstrerror(fd))
#         raise "#{filename}: #{err}"
#       end
#       hdr = uninitialized LibRPM::Header
#       begin
#         RPM.transaction do |ts|
#           rc = LibRPM.rpmReadPackageFile(ts.ptr, fd, filename, pointerof(hdr))
#         end
#       ensure
#         LibRPM.Fclose(fd)
#       end
#       initialize(hdr)
#     end
#   end
#
#   class TagData
#     getter ptr : LibRPM::TagData
#
#     def initialize
#       @ptr = LibRPM.rpmtdNew
#     end
#
#     def finalize
#       LibRPM.rpmtdFree(@ptr)
#     end
#   end
#
#   class MatchIterator
#     getter ptr : LibRPM::MatchIterator
#
#     include Enumerable(MatchIterator)
#
#     def initialize(@ptr)
#     end
#
#     def each
#     end
#
#     def next_iterator
#       pkg = LibRPM.rpmdbNextIterator(@ptr)
#       if !pkg.null?
#         Package.new(pkg)
#       else
#         nil
#       end
#     end
#
#     def finalize
#       LibRPM.rpmdbFreeIterator(@ptr)
#     end
#   end
#
#   class Transaction
#     getter ptr : LibRPM::Transaction
#
#     def initialize(rootdir : String = "/")
#       @ptr = LibRPM.rpmtsCreate
#       LibRPM.rpmtsSetRootDir(@ptr, rootdir)
#     end
#
#     def finalize
#       LibRPM.rpmtsFree(@ptr)
#     end
#
#     def init_iterator(tag : TagData, val : String)
#       it_ptr = LibRPM.rpmtsInitIterator(@ptr, tag, val, 0)
#       MatchIterator.new(it_ptr)
#     end
#   end
#
#   def self.transaction(*args, &block)
#     ts = Transaction.new(*args)
#     begin
#       yield(ts)
#     ensure
#       ts.finalize
#     end
#   end
# end
#
# t = RPM::Transaction.new
# p RPM::VERSION
