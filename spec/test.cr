require "../src/rule.cr"

module TLpsrc2spec
  class TestRule < Rule
    def collect
      add_package(master = Package.new("master"))
      add_package(sub1 = Package.new("texlive-test"))
      add_package(sub2 = Package.new("master-test"))
    end

    def master_package
      packages("master")
    end
  end
end
