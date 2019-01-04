module RPM
  class File
    property path : String
    property md5sum : String
    property link_to : String
    property size : UInt64
    property mtime : Time
    property owner : String
    property group : String
    property mode : String
    property attr : FileState
    property state : String
    property rdev : String

    def initialize(@path, @md5sum, @link_to, @size, @mtime, @owner,
                   @group, @mode, @attr, @state, @rdev)
    end
  end
end
