module TLpsrc2spec
  class Package
  end

  class Application
  end

  class DependencyNode
    getter package : Package
    getter depends : Set(Package) = Set(Package).new
    getter whatrequires : Set(Package) = Set(Package).new

    def initialize(@package)
    end
  end

  class DependencyTree
    @app : Application
    @tlpkg_map : Hash(String, Package) = {} of String => Package
    getter db : Hash(String, DependencyNode) = {} of String => DependencyNode
    getter unresolved_tlpkg_deps : Hash(String, Set(DependencyNode)) = {} of String => Set(DependencyNode)

    def initialize(@app)
    end

    def all_resolved?
      @unresolved_tlpkg_deps.empty?
    end

    def add(package : Package)
      if @db.has_key?(package.name)
        @db[package.name]
      else
        node = DependencyNode.new(package)
        name = package.name
        @db[name] = node
        package.tlpdb_pkgs.each do |tlpkg|
          tlpname = tlpkg.name.not_nil!
          if (binfiles = tlpkg.binfiles)
            if (arch = binfiles.arch)
              if tlpname.ends_with?(arch)
                tlpname = tlpname[0...(-arch.size)] + "ARCH"
              end
            end
          end
          if @tlpkg_map.has_key?(tlpname)
            if (pkg = @tlpkg_map[tlpname]) != package
              @app.log.warn { "#{tlpname} is provided #{pkg.name}" }
            end
          end

          if (unresolved = @unresolved_tlpkg_deps[tlpname]?)
            unresolved.each do |depnode|
              depnode.depends.add package
            end
            @unresolved_tlpkg_deps.delete(tlpname)
          end

          @tlpkg_map[tlpname] = package
          if (deps = tlpkg.depend)
            deps.each do |dep|
              if @tlpkg_map.has_key?(dep)
                pkg = @tlpkg_map[dep]
                if pkg != package
                  node.depends.add(pkg)
                end
              else
                if (unresolved = @unresolved_tlpkg_deps[dep]?)
                  unresolved.add node
                else
                  @unresolved_tlpkg_deps[dep] = Set{node}
                end
              end
            end
          end
        end
        node
      end
    end
  end
end
