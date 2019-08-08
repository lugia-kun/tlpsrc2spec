require "./strcase"

module TLpsrc2spec
  class MomongaRule < Rule
    VERSION = "2019-2m"

    # Whether generate (compute requires) texlive-japanese-recommended
    # package, which is maintained by texlive-metapackages specfile.
    GENERATE_JAPANESE_RECOMMENDED = false

    class Package < TLpsrc2spec::Package
      def group
        super || "Applications/Publishing"
      end
    end

    TEXMFDIR = File.join(DATADIR, "texmf")
    # TEXMFDISTDIR   = File.join(DATADIR, "texmf-dist")
    TEXMFLOCALDIR   = File.join(DATADIR, "texmf-local")
    TEXMFVARDIR     = File.join(LOCALSTATEDIR, "lib", "texmf")
    TEXMFCONFIGDIR  = File.join(SYSCONFDIR, "texmf")
    TEXLIVE_HOOKDIR = File.join(LOCALSTATEDIR, "run", "texlive")
    TEXMF           = [TEXMFDIR, TEXMFLOCALDIR, TEXMFVARDIR, TEXMFCONFIGDIR]

    HOOK_FILES = {
      File.join(TEXLIVE_HOOKDIR, "run-updmap") => "%{_updmap_hook}",
    }

    {% begin %}
      # Reverse conversion table of exact path to rpmmacro name.
      # These will be evaluated in first to last, so order is important.
      RPM_PATHMACRO_TABLE = [
        # {TEXMFDISTDIR, "%{_texmfdistdir}"},
        {TEXMFVARDIR, "%{_texmfvardir}"},
        {TEXMFCONFIGDIR, "%{_texmfconfigdir}"},
        {TEXMFLOCALDIR, "%{_texmflocaldir}"},
        {TEXMFDIR, "%{_texmfdir}"},
        {% for key, val in HOOK_FILES %}
          { {{key}}, {{val}} },
        {% end %}
        {TEXLIVE_HOOKDIR, "%{_texlive_hookdir}"},
        {BINDIR, "%{_bindir}"},
        {LIBEXECDIR, "%{_libexecdir}"},
        {LIBDIR, "%{_libdir}"},
        {INCLUDEDIR, "%{_includedir}"},
        {SYSCONFDIR, "%{_sysconfdir}"},
        {SHAREDSTATEDIR, "%{_sharedstatedir}"},
        {MANDIR, "%{_mandir}"},
        {INFODIR, "%{_infodir}"},
        {DATADIR, "%{_datadir}"},
        {PERL_VENDORLIB, "%{perl_vendorlib}"},
      ]
    {% end %}

    @tree : DirectoryTree
    @master : Package
    @all_license : Set(String) = Set(String).new
    @ts : RPM::Transaction = RPM::Transaction.new
    @skipped_packages : Array(TLPDB::Package) = [] of TLPDB::Package
    @removing_files : Array(String) = [] of String

    def initialize(*args)
      @tree = DirectoryTree.new
      @master = Package.new("texlive")
      super(*args)
    end

    def arch_name?(name) : String | Tuple(String, String) | Nil
      case name
      when "infra", "config", "image", "installer", "installation"
        nil
      when "win32"
        "win32"
      when /^([^-]+)-([^-]+)$/
        arch = $1
        os = $2
        {$1, $2}
      else
        raise Exception.new("Invalid arch name: #{name}")
      end
    end

    def add_texlive_prefix(name : String)
      String.build { |x| x << "texlive-" << name }
    end

    def add_texlive_prefix_if_required(name : String)
      # if name.starts_with?("texlive-")
      #   log.warn { "Not adding prefix \"texlive-\" for \"#{name}\"" }
      #   return name
      # end
      if name.starts_with?("texlive.")
        return add_texlive_prefix(name.sub(".", "-"))
      end
      # if name.starts_with?("kpathsea") ||
      #    name.starts_with?("ptexenc")
      #  return name
      # end
      add_texlive_prefix(name)
    end

    # Find license resource file
    def see_license(tlpkg : TLPDB::Package, license_name : String? = nil,
                    expected_filename : String = "LICENSE")
      candidates = [] of TLPDB::PathInfo
      {% for name, val in TLPDB::ALL_TAGS_DATA %}
        {% if val[:type] == :files %}
          filessets = tlpkg.{{val[:var_symbol].id}}
          filessets.each do |files|
            files.each do |x|
              io = StringCase::Single.new(x.path)
              # File.basename(x)
              ps = 0
              while (ch = io.next_char)
                if ch == '/'
                  ps = io.pos
                end
              end
              io.pos = ps
              StringCase.strcase(case_insensitive: true) do
                case io
                when "COPYING", "LICENSE", "LICENCE",
                     "GUST-FONT-LICENSE", "GUST-FONT-LICENCE",
                     "GUST-FONT-NOSOURCE-LICENSE",
                     "GUST-FONT-NOSOURCE-LICENCE",
                     "COPYRIGHT", "IPA_Font_License_Agreement"
                  candidates << x
                end
              end
            end
          end
        {% end %}
      {% end %}

      if candidates.empty?
        log.warn do
          String.build do |io|
            io << "License file not found in TL package "
            io << tlpkg.name
            if license_name
              io << " (" << license_name << ")"
            end
          end
        end
        "see \"#{expected_filename}\""
      else
        log.debug { "License file candidates of #{tlpkg.name} (#{license_name})" }
        candidates.each do |cand|
          log.debug { " * #{cand.path} (#{cand.details})" }
        end
        path = candidates.first.path
        "see \"#{File.basename(path)}\""
      end
    end

    def parse_license(tlpkg : TLPDB::Package, tlpdb_license_name : String)
      tlpdb_name = tlpkg.name
      if tlpdb_name
        tlpdb_name_stream = StringCase::Single.new(tlpdb_name)
        StringCase.strcase(complete: true) do
          case tlpdb_name_stream
          when "almfixed"
            # See https://ctan.org/pkg/almfixed
            # File not included
            return "see \"GUST-FONT-LICENSE.txt\""
          when "arphic-ttf", "arphic"
            # See https://ctan.org/pkg/arphic
            # See https://ctan.org/pkg/arphic-ttf
            # arphic does not include the file.
            # arphic-ttf wrongly detected.
            return "see \"ARPHICPL.txt\""
          when "awesomebox"
            # See https://ctan.org/pkg/awesomebox
            # WTFPL (but Momonga does not accept this)
            return "\"WTFPL\""
          when "bbm"
            # See https://ctan.org/pkg/bbm
            log.warn { "License of bbm unknown" }
            return "see \"README\""
          when "bbold-type1"
            # See https://ctan.org/pkg/bbold-type1
            return "see \"README\""
          when "beamertheme-metropolis"
            # See https://ctan.org/tex-archive/macros/latex/contrib/beamer-contrib/themes/metropolis
            # CC-BY-SA 4.0 International
            return "CC-BY-SA"
          when "berenisadf"
            # See https://ctan.org/tex-archive/fonts/berenisadf
            return ["GPLv2", "see \"COPYING\"", "LPPL"]
            # when "blacklettert1"
            #  # See https://ctan.org/tex-archive/fonts/gothic/blacklettert1
            #  # It seems slightly different to LPPL 1.2.
            #  return "LPPL"
          when "borceux", "breakcites"
            # See https://ctan.org/pkg/borceux
            # See https://ctan.org/pkg/breakcites
            return "see \"README\""
          when "calligra", "calligra-type1"
            # See https://ctan.org/tex-archive/fonts/calligra
            # See https://ctan.org/tex-archive/fonts/calligra-type1
            return "see \"README\""
          when "charter"
            # See https://ctan.org/pkg/charter
            return "see \"readme.charter\""
          when "cherokee"
            # See https://ctan.org/tex-archive/fonts/cherokee
            return "see \"cherokee.mf\""
          when "chicago"
            # See https://ctan.org/tex-archive/biblio/bibtex/contrib/chicago
            return "see \"chicago.sty\""
          when "cite"
            # See https://ctan.org/tex-archive/macros/latex/contrib/cite
            return "see \"README\""
          when "cjk-ko"
            # See https://ctan.org/pkg/cjk-ko
            return ["GPL", "LPPL", "Public Domain"]
          when "clock"
            # Detected COPYING is GPLv2
            # (Maybe Incomlete to apply GPL?)
            return "GPLv2"
          when "codepage"
            # See https://ctan.org/pkg/codepage
            return "see \"README\""
          when "colorprofile"
            # See https://ctan.org/pkg/colorprofiles
            return "zlib"
          when "context"
            # See https://ctan.org/pkg/context
            # They say see "readme", but which file is that?
            log.warn { "License documentation of context has not found yet" }
            return "see \"README\""
          when "context-mathsets"
            # See https://ctan.org/pkg/context-mathsets
            # See t-mathsets.tex
            return "Modified BSD"
          when "context-rst"
            # See https://ctan.org/pkg/context-rst
            # from mtx-t-rst.lua.
            return "Modified BSD"
          when "courseoutline"
            # See https://ctan.org/tex-archive/macros/latex/contrib/courseoutline
            # NOTE: courceouline.cls uses CR and LF (not CRLF) for
            #       line-terminator.
            return "see \"courseoutline.cls\""
          when "coursepaper"
            # See https://ctan.org/tex-archive/macros/latex/contrib/coursepaper
            # NOTE: courcepaper.cls uses CR for line-terminator.
            return "see \"coursepaper.cls\""
          when "crossword"
            # See https://ctan.org/pkg/crossword
            return "see \"cwpuzzle.dtx\""
          when "csplain"
            # See https://ctan.org/pkg/csplain
            return "see \"csplain.ini\""
          when "cstex"
            # See https://ctan.org/pkg/cstex
            # They say this document does not mean GPLv2.
            return "see \"lic-gpl.eng\""
          when "cv4tw"
            # See https://ctan.org/pkg/cv4tw
            return "see \"LICENSE\""
          when "dancers"
            # See https://ctan.org/pkg/dancers
            return "see \"dancers.mf\""
          when "de-macro"
            # See https://ctan.org/pkg/de-macro
            return "see \"READNE\""
          when "detex"
            # See https://ctan.org/pkg/detex
            return "see \"README\""
          when "din1505"
            # See https://ctan.org/pkg/din1505
            return "see \"abbrvdin.bst\""
          when "doc-pictex"
            # See https://ctan.org/pkg/doc-pictex
            return "see \"Doc-PiCTeX.txt\""
          when "docbytex"
            # See https://ctan.org/pkg/docbytex
            return "see \"README\""
          when "dotseqn"
            # See https://ctan.org/pkg/dotseqn
            return "see \"dotseqn.dtx\""
          when "doublestroke"
            # See https://ctan.org/pkg/doublestroke
            return "see \"README\""
          when "dvidvi"
            # See https://ctan.org/pkg/dvidvi
            return "see \"README\""
          when "dvips"
            # See https://ctan.org/pkg/dvips
            # The file does not included 'texmf' files
            return ["Public Domain", "GPL", "see \"README\""]
          when "ec"
            # See https://ctan.org/pkg/ec
            return "see \"copyrite.txt\""
          when "electrum"
            # See https://ctan.org/pkg/electrumadf
            return ["LPPL", "GPL"]
          when "elvish"
            # See https://ctan.org/pkg/elvish
            return "see \"README\""
          when "epstopdf"
            # See https://ctan.org/pkg/epstopdf
            return "see \"epstopdf.pl\""
          when "eqname"
            # See https://ctan.org/pkg/eqname
            return "see \"eqname.sty\""
          when "fancynum"
            # See https://ctan.org/pkg/fancynum
            return "LPPL"
          when "fbithesis"
            # See https://ctan.org/pkg/fbithesis
            return "see \"README\""
          when "figflow"
            # See https://ctan.org/pkg/figflow
            return "see \"figflow.tex\""
          when "finbib"
            # See https://ctan.org/pkg/finplain
            return "see \"finplain.bst\""
          when "fltpoint"
            # See https://ctan.org/pkg/fltpoint
            return "LPPL"
          when "fonetika"
            # See https://ctan.org/pkg/fonetika
            # GPL and GUST FONT LICENSE.
            return "see \"README\""
          when "font-change"
            # See https://ctan.org/pkg/font-change
            # CC-BY-SA 3.0 Unported
            return "CC-BY-SA"
          when "font-change-xetex"
            # See https://ctan.org/pkg/font-change-xetex
            # CC-BY-SA 4.0 International
            return "CC-BY-SA"
          when "framed"
            # See https://ctan.org/pkg/framed
            return "see \"framed.sty\""
          when "fundus-calligra"
            # See https://ctan.org/pkg/fundus-calligra
            return "LPPL"
          when "fwlw"
            # See https://ctan.org/pkg/fwlw
            return "see \"fwlw.sty\""
          when "gene-logic"
            # See https://ctan.org/pkg/gene-logic
            return "see \"gn-logic14.sty\""
          when "gentium-tug"
            # See https://ctan.org/tex-archive/fonts/gentium-tug
            # (They say Expat License)
            return ["OFL", "MIT"]
          when "gentle"
            # See https://ctan.org/pkg/gentle
            return "see \"gentle.tex\""
          when "germbib"
            # See https://ctan.org/pkg/germbib
            return "see \"gerabbrv.bst\""
          when "gfsartemisia"
            # See https://ctan.org/pkg/gfsartemisia
            return ["OFL", "LPPL"]
          when "gfsbaskerville"
            # See https://ctan.org/pkg/gfsbaskerville
            return ["OFL", "LPPL"]
          when "gfsdidot"
            # See https://ctan.org/pkg/gfsdidot
            return ["OFL", "LPPL"]
          when "gfsneohellenic"
            # See https://ctan.org/pkg/gfsneohellenic
            return ["OFL", "LPPL"]
          when "gfsporson"
            # See https://ctan.org/pkg/gfsporson
            return ["OFL", "LPPL"]
          when "harvmac"
            # See https://ctan.org/pkg/harvmac
            # CC-BY 3.0 Unported
            return "Creative Commons"
          when "hc"
            # See https://ctan.org/pkg/hc
            return "GPLv2"
          when "hyph-utf8"
            # See https://ctan.org/pkg/hyph-utf8
            # Mainly CC0 but it is not all.
            return "CC0"
          when "hyphen-basque"
            # See https://ctan.org/pkg/bahyph
            return "see \"bahyph.tex\""
          when "hyphen-greek"
            # See https://ctan.org/pkg/elhyphen
            return "see \"copyrite.txt\""
          when "hyphen-turkish"
            # See https://ctan.org/pkg/tkhyph
            return "see \"tkhyph.tex\""
          when "hyphenex"
            # See https://ctan.org/pkg/hyphenex
            return "see \"README\""
          when "ifsym"
            # See https://ctan.org/pkg/ifsym
            return "LPPL"
          when "index"
            # See https://ctan.org/pkg/index
            return ["LPPL", "see \"xplain.bst\""]
          when "jadetex"
            # See https://ctan.org/pkg/jadetex
            return "see \"jadetex.dtx\""
          when "jamtimes"
            # See https://ctan.org/pkg/jamtimes
            return "see \"jamtimes.dtx\""
          when "karnaugh-map" # not "karnaughmap"
            # See https://ctan.org/pkg/karnaugh-map
            return "see \"README.md\""
          when "kastrup"
            # See https://ctan.org/pkg/binhex
            return "see \"binhex.dtx\""
          when "kixfont"
            # See https://ctan.org/pkg/kixfont
            return "see \"kix.mf\""
          when "l2tabu"
            # See https://ctan.org/pkg/l2tabu
            return "see \"l2tabu.tex\""
          when "l2tabu-italian"
            # See https://ctan.org/pkg/l2tabu-italian
            return "see \"l2tabuit.tex\""
          when "latexcourse-rug"
            # See https://ctan.org/pkg/latexcourse-rug
            return "see \"README\""
          when "lhcyr"
            # See https://ctan.org/pkg/lhcyr
            return "see \"README\""
          when "localloc"
            # See https://ctan.org/pkg/localloc
            return "see \"localloc.dtx\""
          when "lshort-german"
            # See https://ctan.org/pkg/lshort-german
            # The full-text license is not included.
            return "see \"README.l2kurz\""
          when "lshort-spanish"
            # See https://ctan.org/pkg/lshort-spanish
            log.warn { "License of lshort-spanish unknown" }
            return "see \"LEAME.utf8\""
          when "lshort-ukr"
            # See https://ctan.org/pkg/lshort-ukr
            # This file is included in the tarball
            log.warn { "License of lshort-ukr unknown" }
            return "see \"README\""
          when "luaxml"
            # See https://ctan.org/pkg/luaxml
            # The full-text file not included
            #
            # The License of Lua changed at Lua 5.0 release. So "Lua
            # license" is ambiguous, and we assumed the luaxml's author
            # followed the change.
            #
            # return "\"Lua\""
            return "MIT"
          when "magaz"
            # See https://ctan.org/pkg/magaz
            return "see \"magaz.sty\""
          when "makeindex"
            # See https://ctan.org/pkg/makeindexk
            # The file is not included in the package
            return "see \"COPYING\""
          when "math-into-latex-4"
            # See https://ctan.org/pkg/math-into-latex-4
            return "see \"README\""
          when "mdputu"
            # See https://ctan.org/pkg/mdputu
            return "see \"mdputu.dtx\""
          when "menu"
            # See https://ctan.org/pkg/menu
            return "LPPL"
          when "metapost-examples"
            # See https://ctan.org/pkg/metapost-examples
            # Seems not to satisfy the application condition of GPL.
            return "GPL"
          when "midnight"
            # See https://ctan.org/pkg/midnight
            return "see \"README\""
          when "mkgrkindex"
            # See https://ctan.org/pkg/greek-makeindex
            return "LPPL"
          when "mpman-ru"
            # See https://ctan.org/pkg/mpman-ru
            log.warn { "License of mpman-ru unknown" }
            return "see \"README\""
          when "mslapa"
            # See https://ctan.org/pkg/mslapa
            return "see \"README\""
          when "nar"
            # See https://ctan.org/pkg/nar
            return "see \"nar.bst\""
          when "nestquot"
            # See https://ctan.org/pkg/nestquot
            return "see \"nestquot.sty\""
          when "newsletr"
            # See https://ctan.org/pkg/newsletr
            return "see \"README\""
          when "nimbus15"
            # See https://ctan.org/pkg/nimbus15
            return "AGPLv3"
          when "ocr-b", "ocr-b-outline"
            # See https://ctan.org/pkg/ocr-b
            # See https://ctan.org/pkg/ocr-b-outline
            return "see \"README\""
          when "oubraces"
            # See https://ctan.org/pkg/oubraces
            return "see \"oubraces.sty\""
          when "passivetex"
            # See https://ctan.org/pkg/passivetex
            return "see \"fotex.sty\""
          when "path"
            # See https://ctan.org/pkg/path
            return "see \"path.sty\""
          when "pictexsum"
            # See https://ctan.org/pkg/pictexsum
            return "see \"README\""
          when "pkuthss"
            # See https://ctan.org/pkg/pkuthss
            return "see \"README\""
          when "plweb"
            # See https://ctan.org/pkg/pl
            return "see \"pl.dtx\""
          when "pnas2009"
            # See https://ctan.org/pkg/pnas2009
            return "see \"pnas2009.bst\""
          when "productbox"
            # See https://ctan.org/pkg/productbox
            return "see \"README\""
          when "ps2pk"
            # See https://ctan.org/pkg/ps2pk
            log.warn { "License of ps2pk unknown" }
            return "see \"README\""
          when "psfrag"
            # See https://ctan.org/pkg/psfrag
            return "see \"psfrag.dtx\""
          when "ptex"
            # See https://ctan.org/pkg/ptex
            # This file is not included.
            return "see \"COPYRIGHT\""
          when "punknova"
            # See https://ctan.org/pkg/punknova
            return "see \"README\""
          when "r_und_s"
            # See https://ctan.org/pkg/r_und_s
            return "see \"README\""
          when "rsfs"
            # See https://ctan.org/pkg/rsfs
            return "see \"README\""
          when "seetexk"
            # See https://ctan.org/pkg/dvibook
            log.warn { "License of dvibook unknown" }
            return "see \"README\""
          when "slideshow"
            # See https://ctan.org/pkg/slideshow
            return "see \"slideshow.mp\""
          when "sort-by-letters"
            # See https://ctan.org/pkg/sort-by-letters
            return "see \"README\""
          when "sphack"
            # See https://ctan.org/pkg/sphack
            return "see \"sphack.sty\""
          when "tabls"
            # See https://ctan.org/pkg/tabls
            return "see \"tabls.sty\""
          when "tds"
            # See https://ctan.org/pkg/tds
            return "see \"README\""
          when "tetex"
            log.warn { "License of tetex is incomplete" }
            return ["LGPLv2+"]
          when "tex-refs"
            # See https://ctan.org/pkg/tex-references
            # This does not satisfy the application condition of GFDL.
            return "GFDL"
          when "threeparttable"
            # See https://ctan.org/pkg/threeparttable
            return "see \"threeparttable.sty\""
          when "tie"
            # See https://ctan.org/pkg/tie
            log.warn { "License of tie unkown" }
            return "see \"README\""
          when "tikz-dimline"
            # See https://ctan.org/pkg/tikz-dimline
            # The full-text file is not included.
            return "\"WTFPL\""
          when "trigonometry"
            # See https://ctan.org/pkg/trigonometry
            return "see \"README.txt\""
          when "tucv"
            # See https://ctan.org/pkg/tucv
            # The full-text file is not included.
            return "CC-BY-SA"
          when "tugboat-plain"
            # See https://ctan.org/pkg/tugboat-plain
            return "see \"tugboat.sty\""
          when "ulem"
            # See https://ctan.org/pkg/ulem
            return "see \"README\""
          when "undergradmath"
            # See https://ctan.org/pkg/undergradmath
            # The full-text license file is not included.
            return "CC-BY-SA"
          when "uppunctlm"
            # See https://ctan.org/pkg/uppunctlm
            # File not included
            return "see \"GUST-FONT-LICENSE.txt\""
          when "uspace"
            # See https://ctan.org/pkg/uspace
            return "MIT"
          when "variablelm"
            # See https://ctan.org/pkg/variablelm
            # File not included
            return "see \"GUST-FONT-LICENSE.txt\""
          when "venturisadf"
            # See https://ctan.org/pkg/venturisadf
            return "LPPL"
          when "version"
            # See https://ctan.org/pkg/version
            return "see \"version.sty\""
          when "vntex"
            # See https://ctan.org/pkg/vntex
            return [
              "GPL",
              "LGPL",
              "LPPL",
              "see \"LICENSE-utopia.txt\"",
            ]
          when "wadalab"
            # See https://ctan.org/pkg/wadalab
            return "see \"README\""
          when "webguide"
            # See https://ctan.org/pkg/webguide
            return "see \"README\""
          when "xcharter"
            # See https://ctan.org/pkg/xcharter
            return [
              "see \"README\"",
              "LPPL",
            ]
          when "xdvi"
            # See https://ctan.org/pkg/xdvi
            log.warn { "License of xdvi unknown" }
            return "see \"README\""
          when "yfonts-t1"
            # See https://ctan.org/pkg/yfonts-t1
            log.warn { "License of yfonts-t1 unknown" }
            return "see \"README\""
          when "2up"
            # According to 2up.tex
            return "LPPL"
          when "abstyles"
            log.warn { "License of abstyles unknown" }
            return "LPPL"
          when "xetex"
            # According to `xetex --help`
            return "see \"COPYING\""
          when "zed-csp"
            return "see \"zed-csp.sty\""
          when "uwmslide"
            # See https://ctan.org/pkg/uwmslide
            return "Artistic"
          when "was"
            # See https://ctan.org/tex-archive/macros/latex/contrib/was
            return "LPPL"
          when "eijkhout"
            # See https://ctan.org/pkg/eijkhout
            return ["GPL", "LPPL"]
          when "preprint"
            # See https://ctan.org/pkg/preprint
            return "LPPL"
          when "ltxmisc"
            # See https://ctan.org/tex-archive/macros/latex/contrib/misc
            return [
              # bibcheck.sty
              "GPLv2+",
              # beletter.cls
              "Public Domain",
              # vrtbexin.sty is Non-Commercial only.
              "see \"vrbexin.sty\"",
              # iagproc.cls, nextpage.sty, texilikechaps.sty, topcapt.sty
              "LPPL",
            ]
          when "fragments"
            # See https://ctan.org/pkg/fragments
            return ["Public Domain", "LPPL"]
          when "frankenstein"
            # See https://ctan.org/pkg/frankenstein
            return ["LPPL", "GPL"]
          when "gothic"
            # See https://ctan.org/pkg/gothic
            return [
              "Public Domain",
              "LPPL",
              "see \"COPYING\"", # blacklettert1
            ]
          when "npp-for-context"
            # See https://github.com/luigiScarso/context-npp
            return "GPLv3"
          when "beebe"
            log.warn { "License of beebe (catalogue biblio) is not known" }
            return "LPPL"
          when "arabi-add"
            # See https://ctan.org/tex-archive/language/arabic/arabi-add
            return "LPPL"
          end
        end
      end

      license = StringCase::Single.new(tlpdb_license_name)
      ret = [] of String
      while !license.eof?
        StringCase.strcase do
          case license
          when "gpl"
            save = license.pos
            ch = license.next_char
            case ch
            when '1'
              # GPLv1?
              ret << "GPL"
            when '2'
              save = license.pos
              ch = license.next_char
              if ch == '+'
                ret << "GPLv2+"
              else
                license.pos = save
                ret << "GPLv2"
              end
            when '3'
              save = license.pos
              ch = license.next_char
              if ch == '+'
                ret << "GPLv3+"
              else
                license.pos = save
                ret << "GPLv3"
              end
            else
              license.pos = save
              ret << "GPL"
            end
          when "lgpl"
            save = license.pos
            StringCase.strcase do
              case license
              when "2.1"
                ret << "LGPLv2"
              when "3"
                ret << "LGPLv3"
              else
                license.pos = save
                ret << "LGPL"
              end
            end
          when "fdl"
            ret << "GFDL"
          when "lppl"
            save = license.pos
            ch = license.next_char
            case ch
            when '1'
              save = license.pos
              StringCase.strcase do
                case license
                when ".2"
                  ret << "LPPL"
                when ".3"
                  save = license.pos
                  ch = license.next_char
                  case ch
                  when 'a', 'b', 'c'
                    ret << "LPPL"
                  else
                    license.pos = save
                    ret << "LPPL"
                  end
                else
                  license.pos = save
                  ret << "LPPL"
                end
              end
            else
              license.pos = save
              ret << "LPPL"
            end
          when "cc0"
            ret << "CC0"
          when "pd"
            ret << "Public Domain"
          when "ofl"
            ret << "OFL"
          when "mit"
            ret << "MIT"
          when "apache2"
            ret << "ASL 2.0"
          when "bsd"
            save = license.pos
            ch = license.next_char
            case ch
            when '2', '4'
              ret << "BSD" # Momonga does not approve yet.
            when '3'
              ret << "Modified BSD"
            else
              license.pos = save
              ret << "BSD" # Momonga does not approve yet.
            end
          when "cc-by-"
            StringCase.strcase do
              case license
              when "1", "2", "3", "4"
                ret << "Creative Commons"
              when "sa-1", "sa-2", "sa-3", "sa-4"
                ret << "CC-BY-SA"
              when "nd-1", "nd-2", "nd-3", "nd-4"
                # CC-BY-ND
                log.error { "#{tlpkg.name}: CC-BY-ND is not \"free culture license\"" }
                stat = true
                ret << see_license(tlpkg)
              when "nc-"
                StringCase.strcase do
                  case license
                  when "1", "2", "3", "4"
                    # CC-BY-NC
                    log.error { "#{tlpkg.name}: CC-BY-NC is not \"free culture license\"" }
                    stat = 1
                    ret << see_license(tlpkg)
                  when "sa-1", "sa-2", "sa-3", "sa-4"
                    # CC-BY-NC-SA
                    log.error { "#{tlpkg.name}: CC-BY-NC-SA is not \"free culture license\"" }
                    stat = 1
                    ret << see_license(tlpkg)
                  when "nd-1", "nd-2", "nd-3", "nd-4"
                    # CC-BY-NC-ND
                    log.error { "#{tlpkg.name}: CC-BY-NC-ND is not \"free culture license\"" }
                    stat = 1
                    ret << see_license(tlpkg)
                  else
                    log.error { "Unknown lincese: #{tlpdb_license_name}" }
                    return nil
                  end
                end
              else
                log.error { "Unknown lincese: #{tlpdb_license_name}" }
                return nil
              end
            end
          when "artistic"
            save = license.pos
            ch = license.next_char
            if ch == '2'
              ret << "Artistic"
            else
              license.pos = save
              ret << "Artistic"
            end
          when "knuth" # See https://ctan.org/license/knuth
            ret << see_license(tlpkg, "Knuth License")
          when "gfl"
            ret << see_license(tlpkg, "GUST Font License")
          when "gfsl" # GUST Font (Source) License
            ret << see_license(tlpkg, "GUST Font Source License")
          when "opl"
            ret << see_license(tlpkg, "Open Publication License")
          when "other-free"
            ret << see_license(tlpkg, "other-free license")
          when "collection"
            log.error { "Please inspect collection license for #{tlpkg.name}" }
            return nil
          when "noinfo"
            log.error { "Please inspect noinfo license for #{tlpkg.name}" }
            return nil
          else
            log.error { "Unknown lincese for #{tlpkg.name}: #{tlpdb_license_name}" }
            return nil
          end
        end
      end
      ret
    end

    def package_name_from_tlpdb_name(name : String)
      case name
      when /^00texlive/
        nil
      when /^texlive-scripts/
        nil
      when /^texlive\.infra\./
        nil
      when "collection-wintools"
        nil
      when "collection-texworks", "texworks"
        # TL does not provide TeXworks for UNIX-like OSs.
        nil
      when /^psutils/, /^t1utils/
        nil
      when "axessibility", "guide-latex-fr" # License issue.
        nil
      when /^(.*)\.([^\.]+)$/
        if $2.ends_with?("-linux")
          bin_name = String.build { |x| x << $1 << "-bin" }
          add_texlive_prefix_if_required(bin_name)
        elsif !arch_name?($2)
          log.warn do
            String.build do |x|
              x << "Package name with dot(s): " << name
            end
          end
          add_texlive_prefix_if_required(name)
        else
          nil
        end
      else
        add_texlive_prefix_if_required(name)
      end
    end

    macro make_tlpkg_modify_m(pkg)
      TLPDB::Package.new(
        {% for name, val in TLPDB::ALL_TAGS_DATA %}
          {% n = val[:var_symbol] %}
          {% c = val[:const_symbol] %}
          {% t = val[:type] %}
          {% if t == :exec %}
            {% a = "[] of TLPDB::Execute" %}
          {% elsif t == :files %}
            {% a = "[] of TLPDB::Files" %}
          {% elsif t == :postact %}
            {% a = "[] of TLPDB::PostAction" %}
          {% elsif t == :words %}
            {% a = "[] of String" %}
          {% else %}
            {% a = "nil" %}
          {% end %}
          {% if pkg.is_a?(Var) %}
            {% v = pkg.stringify %}
          {% else %}
            {% v = "(" + pkg.stringify + ")" %}
          {% end %}
          {% b = v + "." + n.id.stringify %}
          {{n.id}}: {{yield(n, t, c, a.id, b.id)}},
        {% end %}
      )
    end

    def make_tlpkg_modify(pkg : TLPDB::Package, &block)
      make_tlpkg_modify_m(pkg) do |n, t, c, a, b|
        {% begin %}
          yield({{n}}, {{t}}, TLPDB::Tag::{{c}}, {{a}}, {{b}})
        {% end %}
      end
    end

    macro tlpkg_modify_without(n, t, a, b, **args)
      {% cond = false %}
      {% if (nn = args[:names]) %}
        {% cond = nn.any? { |x| x == n } %}
      {% end %}
      {% if !cond && (tt = args[:types]) %}
        {% cond = tt.any? { |x| x == t } %}
      {% end %}
      {% if cond %}
        {{a}}
      {% else %}
        {{b}}
      {% end %}
    end

    def make_solib_package(name : String, *,
                           libname : String = "lib" + name,
                           include_subdir : String | Array(String)? = name,
                           has_include : Bool = true,
                           tlpkg : TLPDB::Package | String? = name,
                           has_static : Bool = true,
                           pkgconfig : String? = name)
      if tlpkg.is_a?(String)
        tlpkg = app.tlpdb[tlpkg]
      end
      kpsedevname = package_name_from_tlpdb_name(name + "-devel")
      kpselibname = package_name_from_tlpdb_name(name + "-libs")
      if kpsedevname
        kpsedev = Package.new(kpsedevname,
          summary: "Development files for #{name}",
          group: "Development/Libraries",
          archdep: true,
          description: <<-EOD)
        This package contains development files for #{name}.
        EOD
        if has_include
          if include_subdir
            if include_subdir.responds_to?(:each)
              dirs = include_subdir
            else
              dirs = {include_subdir}
            end
          else
            dirs = {"*"}
          end
          dirs.each do |x|
            kpsedev.files << FileEntry.new(File.join(INCLUDEDIR, x))
          end
        end
        if has_static
          kpsedev.files << FileEntry.new(File.join(LIBDIR, "#{libname}.a"))
        end
        kpsedev.files << FileEntry.new(File.join(LIBDIR, "#{libname}.so"))
        if pkgconfig
          kpsedev.files << FileEntry.new(File.join(LIBDIR, "pkgconfig",
            pkgconfig + ".pc"))
        end
      end
      if kpselibname
        kpselib = Package.new(kpselibname,
          summary: "Library files of #{name}",
          group: "System Environment/Libraries",
          archdep: true,
          description: <<-EOD)
        This package contains library files of #{name}.
        EOD
        kpselib.files << FileEntry.new(File.join(LIBDIR, "#{libname}.so.*"))
      end
      if kpsedev && kpselib
        kpsedev.requires << "#{kpselib.name} == %{version}-%{release}"
      end
      xtlpkg = nil
      if tlpkg
        # Create TLPDB package with no files, no dependencies, no executes,
        # and no postactions.
        xtlpkg = make_tlpkg_modify_m(tlpkg) do |n, t, c, a, b|
          tlpkg_modify_without({{n}}, {{t}}, {{a}}, {{b}},
            names: {:depends},
            types: {:files, :exec, :postact})
        end
      end
      if kpsedev
        if xtlpkg
          kpsedev.tlpdb_pkgs << xtlpkg
        end
        add_package(kpsedev)
      end
      if kpselib
        if xtlpkg
          kpselib.tlpdb_pkgs << xtlpkg
        end
        add_package(kpselib)
      end
      [kpsedev, kpselib].compact
    end

    def create_package_from_tlpdb
      log.info "Creating package from tlpdb"
      app.tlpdb.each do |tlpkg|
        name = tlpkg.name.not_nil!

        pkgname = package_name_from_tlpdb_name(name)
        if pkgname.nil?
          log.debug { String.build { |x| x << "Skipping package " << name } }
          @skipped_packages << tlpkg
          next
        end
        if (pkg = packages?(pkgname))
          log.info { "Adding #{name} to #{pkgname}" }
          pkg.tlpdb_pkgs << tlpkg
          next
        end

        log.info do
          String.build do |x|
            x << "Creating package " << pkgname << " of " << name
          end
        end

        add_package(Package.new(pkgname, tlpdb_pkgs: [tlpkg]))
      end

      # Set flag whether any architecture depend files is contained
      # or not.
      each_package do |pkg|
        tlpkgs = pkg.tlpdb_pkgs
        pkg.archdep = tlpkgs.any? do |tlpkg|
          !tlpkg.binfiles.empty?
        end
      end

      # ## After this archdep must be set. (if not set, defaults to `false`)

      # Create packages contains shared libraries, built by texlive.
      make_solib_package("kpathsea")
      ptexenc = make_solib_package("ptexenc", tlpkg: nil)
      ptexenc.each do |pkg|
        pkg.license = ["Modified BSD"]
      end
      make_solib_package("texlua", libname: "libtexlua53", tlpkg: "luatex",
        include_subdir: "texlua53", pkgconfig: "texlua53")
      make_solib_package("texluajit", tlpkg: "luatex")
      make_solib_package("synctex")

      # Package texlive-filesystem is the bare texlive-filesystem
      # tree.
      tl_fs_pkg = Package.new("texlive-filesystem",
        summary: "TeX Live filesystem",
        license: ["GPL"],
        archdep: false,
        group: "System Environment/Base",
        description: <<-EOD)
      Filesystem tree of TeX Live distribution.
      EOD
      add_package(tl_fs_pkg)

      # Package cleanup-packages-texlive is used for cleaning up old
      # texlive packages, which can be used for stable-release update.
      tl_cleanup = Package.new("cleanup-packages-texlive",
        summary: "Cleanup texlive-related package",
        license: ["GPL"],
        archdep: false,
        group: "System Environment/Base",
        description: <<-EOD)
      cleanup packages old TeX Live distribution.
      EOD
      add_package(tl_cleanup)
      if (old_cleanup = installed_db.package?(tl_cleanup.name))
        log.warn { "Adding existing #{tl_cleanup.name} obsoletes..." }
        old_cleanup.each_value do |pkg|
          pkg.obsoletes.each do |obso|
            tl_cleanup.add_obsolete(obso)
          end
        end
      end

      stat = false
      each_package do |pkg|
        tlpkgs = pkg.tlpdb_pkgs
        archdepname = nil

        # Build Summary field.
        #
        # Summary field will be built from the first tlpkg data.
        if (tlpkg = tlpkgs.first?)
          if pkg.summary.nil?
            if pkg.archdep?
              n = tlpkg.name.not_nil!
              ni = n.byte_index('.'.ord)
              archdepname = n[0...ni]
              summary = String.build do |io|
                io << "Binary files for TeX Live Package '"
                io << archdepname
                io << "'"
              end
              archdeppkg = @app.tlpdb[archdepname]?
            else
              if (sdesc = tlpkg.shortdesc)
                summary = sdesc.gsub('%', "%%")
              else
                name = tlpkg.name.not_nil!
                log.warn { "Package #{name} has no shortdesc" }
                summary = String.build do |io|
                  io << "TeX Live Package: " << name
                end
              end
            end
            pkg.summary = summary
          end
        end

        # Build description field
        if pkg.description.nil?
          begin
            pkg.description = String.build do |io|
              if pkg.archdep?
                io << "Binary files for TeX Live Package '"
                io << archdepname.not_nil!
                io << "'"
              else
                nlongdesc = tlpkgs.count do |tlpkg|
                  l = tlpkg.longdesc
                  l && l.size > 0
                end
                print_name = nlongdesc > 1
                first = true
                tlpkgs.each do |tlpkg|
                  longdesc = tlpkg.longdesc
                  if !longdesc || longdesc.size == 0
                    next
                  end
                  longdesc = longdesc.gsub('%', "%%")
                  if print_name
                    if !first
                      io << "\n"
                    end
                    io << "(" << tlpkg.name << ")\n"
                  end
                  io << longdesc << "\n"
                  first = false
                end
              end
            end
          rescue e : NilAssertionError
            if archdepname.nil?
              log.error { "Please also set description for '#{pkg.name}' if you set own summary." }
            else
              raise e
            end
            stat = true
          end
        end

        # Arch dependent packages (includes executable/library binary
        # files) should include base tlpkg to get license info.
        if pkg.archdep? && tlpkgs.empty?
          if archdeppkg
            tlpkgs << archdeppkg
          end
        end

        # Collect license information from tlpkg data.
        tlpkgs.each do |tlpkg|
          if (ctan_license = tlpkg.catalogue_license)
            if (lics = parse_license(tlpkg, ctan_license))
              if lics.responds_to?(:each)
                lics.each do |lic|
                  pkg.license << lic
                end
              else
                pkg.license << lics
              end
            else
              stat = true
            end
          end
        end

        # Use LPPL as metapackage provided by upstream.
        if !stat && !tlpkgs.empty? && pkg.license.empty?
          pkg.license << "LPPL"
        end

        # Write out list of licenses.
        log.info do
          String.build do |io|
            io << "License of " << pkg.name << ": "
            f = false
            pkg.license.each do |lic|
              if f
                io << " and "
              end
              io << lic
              f = true
            end
          end
        end
      end
      each_package do |pkg|
        pkg.license.each do |lic|
          if lic.starts_with?("see ")
            @all_license.add("see \"LICENSE\"")
          else
            @all_license.add(lic)
          end
        end
      end
      if @all_license.empty?
        log.warn("No license information collected, using just LPPL instead.")
        @all_license.add("LPPL")
      end
      if stat
        log.fatal { "Stopping by previous error(s). Please check." }
        exit 1
      end

      if (fontutils = packages?("texlive-collection-fontutils"))
        fontutils.add_require "psutils"
        fontutils.add_require "t1utils"
      end

      if (xindy = packages?("texlive-xindy-bin"))
        xindy.add_require "clisp"
      end

      if GENERATE_JAPANESE_RECOMMENDED
        add_package(Package.new("texlive-japanese-recommended",
          summary: "TeX Live: recommended packages for Japanese users",
          description: <<-EOD))
        This meta-package contains a collection of recommended packages for
        Japanese texlive users.
        EOD
      end
    end

    def make_config_file(file : String)
      base = if file.starts_with?("texmf-dist/")
               file.sub("texmf-dist/", "")
             elsif file.starts_with?("RELOC/")
               file.sub("RELOC/", "")
             else
               file
             end
      {File.join(TEXMFCONFIGDIR, base), base}
    end

    def add_config_file(pkg : TLpsrc2spec::Package, path : String)
      cnffile, apath = make_config_file(path)
      log.warn { "Creating in sysconfdir: #{cnffile}" }
      conf = FileConfig.new
      e = FileEntry.new(cnffile, config: conf)
      pkg.files << e
      pkg.install_script = String.build do |str|
        if pkg.install_script
          str << pkg.install_script
        end
        base = File.basename(apath)
        adir = File.dirname(apath)
        root = "%{buildroot}"
        destdir = File.join("%{_texmfconfigdir}/", adir)
        locadir = File.join("%{_texmfdir}/", adir)
        destnam = File.join(destdir, base)
        locanam = File.join(locadir, base)
        str << "%{__mkdir} -p " << root << destdir << "\n"
        str << "%{__mv} " << root << locanam << " " << root << destnam << "\n"
        str << "%{__ln_s} " << destnam << " " << root << locanam << "\n\n"
      end
    end

    def add_info_file(pkg : TLpsrc2spec::Package, path : String)
      xpath = File.join(INFODIR, path)
      xname = File.join("%{_infodir}", path)
      base = File.basename(xpath)
      pkg.post = String.build do |str|
        if pkg.post
          str << pkg.post
        end
        str << "/sbin/install-info " << xname << " %{_infodir}/dir || :\n"
      end
      pkg.preun = String.build do |str|
        if pkg.preun
          str << pkg.preun
        end
        str << "test $1 -eq 0 && /sbin/install-info --delete " << xname
        str << " %{_infodir}/dir || :\n"
      end
      xpath + "*"
    end

    def make_require(pkg : TLpsrc2spec::Package,
                     f : RPM::Sense = RPM::Sense::GREATER | RPM::Sense::EQUAL)
      v = RPM::Version.new("%{version}")
      RPM::Require.new(pkg.name, v, f, nil)
    end

    def create_biber_module_package(tlbiber : TLPDB::Package,
                                    rpmbiber : TLpsrc2spec::Package)
      perl_mod = packages?("perl-biber")
      if perl_mod.nil?
        nperl_mod = Package.new("perl-biber",
          group: "Development/Libraries",
          license: rpmbiber.license,
          summary: "Library files for TeX Live 'biber'",
          description: <<-EOD)
        Perl library files of Biber.
        EOD
        nperl_mod.files << FileEntry.new(File.join(PERL_VENDORLIB, "Biber.pm"))
        nperl_mod.files << FileEntry.new(File.join(PERL_VENDORLIB, "Biber"))
        # For avoid adding Requires: %files, scripts.
        nperl_mod.tlpdb_pkgs << make_tlpkg_modify_m(tlbiber) do |n, t, c, a, b|
          tlpkg_modify_without({{n}}, {{t}}, {{a}}, {{b}},
            names: {:depends},
            types: {:files, :exec, :postact})
        end
        add_package(nperl_mod)
        dep = make_require(nperl_mod)
      else
        dep = make_require(perl_mod)
      end
      old = rpmbiber.add_require dep
      if dep != old && perl_mod
        log.warn { "Really multiple package requires 'biber' perl Lib?" }
      end
    end

    def expand_tlpdb_files(pkg : TLpsrc2spec::Package, tlpkg : TLPDB::Package,
                           tag : TLPDB::Tag, files : TLPDB::Files,
                           *, exclude : Bool)
      stat = false
      files.each do |pinfo|
        path = pinfo.path
        xpath = path
        doc = false
        skip = false
        pathparser = StringCase::Single.new(path)
        StringCase.strcase do
          case pathparser
          when "bin/"
            arch = pathparser.gets('/').not_nil!
            pos_save = pathparser.pos
            base = pathparser.gets_to_end
            pathparser.pos = pos_save
            xpath = File.join(BINDIR, base)
            StringCase.strcase do
              case pathparser
              when "man", "teckit_compile", "tlmgr", "rungs"
                skip = true
              when "lualatex"
                if !exclude
                  luajitlatex = File.join(BINDIR, "luajitlatex")
                  log.info {
                    "Adding '#{luajitlatex}' to #{pkg.name} (TL: #{tlpkg.name})"
                  }
                  e = FileEntry.new(luajitlatex, tlpdb_tag: tag)
                  pkg.files << e
                end
              when "biber"
                if !exclude
                  create_biber_module_package(tlpkg, pkg)
                end
              when "xdvi-xaw"
                # They use XAW version of xdvi, but we have openmotif.
                # So packaging motif version.
                xpath = File.join(BINDIR, "xdvi-motif")
              when "xindy.mem"
                # Use %{_libdir}/xindy/xindy.mem as xindy memory file.
                xpath = File.join(LIBEXECDIR, "xindy", "xindy.mem")
              when "xindy.run"
                # Force use %{_bindir}/clisp directly
                skip = true
              end
            end
          when "texmf-dist/", "RELOC/"
            pos_save = pathparser.pos
            xpath = File.join(TEXMFDIR, pathparser.gets.not_nil!)
            pathparser.pos = pos_save
            StringCase.strcase do
              case pathparser
              when "dvipdfm/config",
                   "dvipdfmx/dvipdfmx.cfg",
                   "dvips/config/config.ps",
                   "scripts/match_parens",
                   "scripts/mf2pt1",
                   "scripts/urlbst",
                   "tex/amstex/base/amsppt.sti",
                   "tex/generic/tex-ini-files/pdftexconfig.tex",
                   "tex/generic/config/language.def",
                   "tex/generic/config/language.dat.lua",
                   "tex/generic/config/language.dat",
                   "tex/lambda/config/language.dat",
                   "tex/mex/base/mexconf.cfg",
                   "tex/plain/cyrplain/cyrtex.cfg",
                   "web2c/fmtutil.cnf",
                   "web2c/mktex.cnf",
                   "web2c/texmf.cnf",
                   "web2c/texmfcnf.lua",
                   "web2c/updmap.cfg",
                   "xdvi/XDvi"
                if !exclude
                  add_config_file(pkg, path)
                end
              when "scripts/texlive/tlmgr.pl",
                   "scripts/texlive/tlmgrgui.pl",
                   "scripts/texlive/uninstall-win32.pl",
                   "scripts/texlive/uninstq.vbs"
                log.debug { "Skipping TLPKG scripts: #{path}" }
                skip = true
              when "web2c/fmtutil-hdr.cnf",
                   "web2c/updmap-hdr.cfg"
                log.debug { "Skipping extra config: #{path}" }
                skip = true
              when "doc/info/"
                pos_save = pathparser.pos
                StringCase.strcase do
                  case pathparser
                  when "dir"
                    log.debug { "Skipping info/dir" }
                    skip = true
                  else
                    pathparser.pos = pos_save
                    if path.ends_with?(".info")
                      xpath = add_info_file(pkg, pathparser.gets.not_nil!)
                      log.debug { "Info page #{path} -> #{xpath}" }
                    end
                  end
                end
              when "doc/man/"
                pos_save = pathparser.pos
                if !path.ends_with?(".pdf") && !path.ends_with?("Makefile")
                  xpath = File.join(MANDIR, pathparser.gets.not_nil!) + "*"
                  log.debug { "Man page #{path} -> #{xpath}" }
                  pathparser.pos = pos_save
                end
                StringCase.strcase do
                  case pathparser
                  when "man1/install-tl.1",
                       "man1/install-tl.man1.pdf",
                       "man1/tlmgr.1",
                       "man1/tlmgr.man1.pdf"
                    log.debug { "Skipping TLPKG file: #{path}" }
                    skip = true
                  end
                end
              end
            end
          when ".mkisofsrc", "autorun.inf",
               "install-tl", "install-tl-windows.bat",
               "tl-tray-menu.exe" # , "tlpkg/"
            log.debug { "Skipping TLPKG file: #{path}" }
            xpath = File.join(TEXMFDIR, path)
            skip = true
          when "tlpkg/"
            xpath = File.join(TEXMFDIR, path)
            StringCase.strcase do
              case pathparser
              when "installer/", "tltcl/"
                log.debug { "Skipping TLPKG file: #{path}" }
                skip = true
              when "gpg/"
                # Who use GPG keys?
                skip = true
              when "README"
                # "extra" archive does not include this file.
                skip = true
              end
            end
          when "release-texlive.txt",
               "README", "readme-txt.dir/", "readme-html.dir/",
               "LICENSE", "license", "doc.html", "index.html"
            log.debug { "Document: #{path}" }
            xpath = File.join(TEXMFDIR, xpath)
            doc = true
          else
            log.error { "Unknown fullpath for: #{path}" }
            skip = true
            stat = true
          end
        end

        if path.ends_with?(".exe") || path.ends_with?(".dll")
          log.debug { "Windows executable file: #{xpath}" }
          skip = true
        end
        case tag
        when TLPDB::Tag::DOCFILES
          doc = true
        end

        if skip
          log.warn { "Skipping file: #{xpath}" }
        end

        if skip || exclude
          # If an absolute path is set, remove it from installation tree.
          if xpath.starts_with?('/')
            @removing_files << xpath
          end
          next
        end

        entry = FileEntry.new(xpath, doc: doc, tlpdb_tag: tag)
        pkg.files << entry
      end
      stat
    end

    def add_fmt_files(pkg, fmts : Array(TLPDB::Execute::AddFormat))
      fmts.each do |fmt|
        engine = StringCase::Single.new(fmt.engine)
        {% begin %}
          {% mfa = [] of String %}
          {% for mfengine in ["mf", "mflua", "mfluajit"] %}
            {% mfa << mfengine %}
            {% mfa << mfengine + "-nowin" %}
          {% end %}
          StringCase.strcase(complete: true) do
            case engine
            when {{mfa.splat}}
              dir = File.join(TEXMFVARDIR, "web2c", "metafont")
              pkg.files << FileEntry.new(File.join(dir, fmt.name + ".base"))
              pkg.files << FileEntry.new(File.join(dir, fmt.name + ".log"))
            else
              dir = File.join(TEXMFVARDIR, "web2c", fmt.engine)
              pkg.files << FileEntry.new(File.join(dir, fmt.name + ".fmt"))
              pkg.files << FileEntry.new(File.join(dir, fmt.name + ".log"))
            end
          end
        {% end %}
      end
    end

    def create_file_entries
      @tree.clear

      tl_fs_pkg = packages("texlive-filesystem")
      miss = FileConfig.new(missingok: true)
      TEXMF.each do |texmfdir|
        node = @tree.mkdir(texmfdir)
        tl_fs_pkg.files << FileEntry.new(texmfdir, dir: true)
        node.package = tl_fs_pkg

        if texmfdir != TEXMFLOCALDIR
          ls_r = FileEntry.new(File.join(texmfdir, "ls-R"), ghost: true)
          ls_u = FileEntry.new(File.join(texmfdir, "%{ls_R_needs_update}"), ghost: true)
          tl_fs_pkg.files << ls_r
          tl_fs_pkg.files << ls_u
        end
      end
      tl_fs_pkg.files << FileEntry.new(TEXLIVE_HOOKDIR, dir: true)
      HOOK_FILES.each_key do |hook|
        tl_fs_pkg.files << FileEntry.new(hook, ghost: true)
      end

      log.info "Creating package file entries"
      stat = false
      each_package do |pkg|
        pkg.tlpdb_pkgs.each do |tlpkg|
          {% for name, val in TLPDB::ALL_TAGS_DATA %}
            {% if val[:type] == :files %}
              exclude = false
              {% if val[:var_symbol] == :srcfiles %}
                # Include source files when there are no run files.
                if !tlpkg.runfiles.empty?
                  exclude = true
                end
              {% end %}
              filessets = tlpkg.{{val[:var_symbol].id}}
              filessets.each do |files|
                ns = expand_tlpdb_files(pkg, tlpkg,
                                        TLPDB::Tag::{{val[:const_symbol].id}},
                                        files, exclude: exclude)
                stat = stat || ns
              end
            {% end %}
          {% end %}

          fmts = tlpkg.executes.compact_map do |ex|
            if ex.is_a?(TLPDB::Execute::AddFormat)
              ex.as(TLPDB::Execute::AddFormat)
            else
              nil
            end
          end
          add_fmt_files(pkg, fmts)
        end
        pkg.files.uniq! do |entry|
          entry.path
        end
        pkg.files.each do |entry|
          if entry.dir?
            e = @tree.mkdir(entry.path)
          else
            e = @tree.insert(entry.path)
          end
          e.package = pkg
        end
      end
      # Assist removing files excluded packages, with marking their
      # files to be excluded (but not all though...)
      @skipped_packages.each do |skipped_pkg|
        {% for name, val in TLPDB::ALL_TAGS_DATA %}
          {% if val[:type] == :files %}
            filessets = skipped_pkg.{{val[:var_symbol].id}}
            filessets.each do |files|
              ns = expand_tlpdb_files(tl_fs_pkg, skipped_pkg,
                                      TLPDB::Tag::{{val[:const_symbol].id}},
                                      files, exclude: true)
              stat = stat || ns
            end
          {% end %}
        {% end %}
      end
      if stat
        log.fatal { "Please check previous error" }
        exit 1
      end

      log.info "Adding additoinal files"
      begin
        infra = packages("texlive-texlive-infra")
        tlpdb = File.join(TEXMFDIR, "tlpkg", "texlive.tlpdb")
        infra.files << FileEntry.new(tlpdb)

        xdvi = packages("texlive-xdvi")
        desktop = File.join(DATADIR, "applications", "xdvi.desktop")
        xdvi.files << FileEntry.new(desktop)

        asy = packages("texlive-asymptote")
        [
          File.join(TEXMFDIR, "/doc/asymptote/asy-faq.ascii"),
          File.join(TEXMFDIR, "/doc/asymptote/asy-faq.html/index.html"),
          File.join(TEXMFDIR, "/doc/asymptote/asy-faq.html/section1.html"),
          File.join(TEXMFDIR, "/doc/asymptote/asy-faq.html/section2.html"),
          File.join(TEXMFDIR, "/doc/asymptote/asy-faq.html/section3.html"),
          File.join(TEXMFDIR, "/doc/asymptote/asy-faq.html/section4.html"),
          File.join(TEXMFDIR, "/doc/asymptote/asy-faq.html/section5.html"),
          File.join(TEXMFDIR, "/doc/asymptote/asy-faq.html/section6.html"),
          File.join(TEXMFDIR, "/doc/asymptote/asy-faq.html/section7.html"),
          File.join(TEXMFDIR, "/doc/asymptote/asy-faq.html/section8.html"),
          File.join(TEXMFDIR, "/doc/asymptote/asy-faq.html/section9.html"),
        ].each do |path|
          asy.files << FileEntry.new(path, doc: true)
        end
      end

      log.info "Collecting directories preferred to be contained by filesystem"
      TEXMF.each do |mfdir|
        ent = @tree[mfdir].as(DirectoryNode)
        ent.entries.each do |name, sub|
          if sub.is_a?(DirectoryNode)
            gosub = false
            if name == "tex" || name == "fonts"
              gosub = true
            end
            if gosub
              oldcwd = @tree.cwd
              begin
                sub.entries.each do |ns, subent|
                  if !subent.is_a?(DirectoryNode)
                    next
                  end
                  tl_fs_pkg.files << FileEntry.new(subent.path, dir: true)
                  subent.package = tl_fs_pkg
                  if name == "fonts"
                    @tree.cwd = subent
                    pubdir = @tree["public"]?
                    if pubdir.is_a?(DirectoryNode)
                      tl_fs_pkg.files << FileEntry.new(pubdir.path, dir: true)
                      pubdir.package = tl_fs_pkg
                    end
                  end
                end
              ensure
                @tree.cwd = oldcwd
              end
            end
            tl_fs_pkg.files << FileEntry.new(sub.path, dir: true)
            sub.package = tl_fs_pkg
          end
        end
      end

      log.info "Directory compacting"
      dirs = [] of DirectoryNode
      filesystem_pkg = Package.new("filesystem")
      # RPM.transaction do |ts|
      begin
        rpmfspkgs = {} of String => RPM::Package

        [
          PREFIX, DATADIR, BINDIR, LIBDIR, INCLUDEDIR,
          SHAREDSTATEDIR, LOCALSTATEDIR, SYSCONFDIR,
          MANDIR, INFODIR, PERL_VENDORLIB, PKGCONFIGDIR,
        ].each do |dir|
          iter = @ts.init_iterator(RPM::DbiTag::BaseNames, dir)
          begin
            iter.each do |pkg|
              name = pkg.name
              if !rpmfspkgs.has_key?(name)
                rpmfspkgs[name] = pkg
              end
            end
          ensure
            iter.finalize
          end
        end

        rpmfspkgs.each do |name, rpmfspkg|
          rpmfspkg.files.each do |entry|
            if (ent = @tree[entry.path]?)
              ent.package = filesystem_pkg
            end
          end
        end
      end

      %w[filesystem perl pkgconfig].each do |file_system_base_pkg|
        # RPM.transaction do |ts|
        begin
          iter = @ts.init_iterator(RPM::DbiTag::Name, file_system_base_pkg)
          begin
            rpmfspkg = iter.first
            rpmfspkg.files.each do |entry|
              if (ent = @tree[entry.path]?)
                ent.package = filesystem_pkg
              end
            end
          ensure
            iter.finalize
          end
        end
      end

      # "nil-package" is a mark that traversed but still no package
      # has been set. (`nil` is a mark that not traversed yet.)
      nil_pkg = Package.new("nil-package")
      @tree.each_entry_breadth.to_a.reverse_each do |entry|
        if entry.is_a?(DirectoryNode)
          pkg = entry.package
          if pkg
            pkg.files << FileEntry.new(entry.path, dir: true)
          else
            if entry.entries.size == 0
              log.warn { "Empty directry: #{entry.path}" }
            else
              log.fatal do
                String.build do |str|
                  str << "Non-empty directory `"
                  str << entry.path << "` found without any package"
                end
              end
              pkg.not_nil!
            end
          end
        end
        parent = entry.parent
        # log.debug do
        #   String.build do |io|
        #     io << parent.path << ": "
        #     if (pkg = parent.package)
        #       io << pkg.name
        #     else
        #       io << "(not set)"
        #     end
        #   end
        # end

        parent_pkg = parent.package
        entry_pkg = entry.package.not_nil!
        if parent_pkg.nil?
          if entry.package
            parent.package = entry_pkg
          else
            parent.package = nil_pkg
          end
        elsif parent_pkg != entry_pkg
          if parent_pkg != filesystem_pkg && parent_pkg != nil_pkg
            parent.package = tl_fs_pkg
          end
        end
      end

      log.info { "Adding directory hierarchy requires..." }
      @tree.each_entry_breadth do |entry|
        pkg = entry.package
        if pkg && pkg != tl_fs_pkg && (pkg = packages?(pkg.name))
          while (parent = entry.parent) != entry
            if (dirpkg = parent.package)
              if dirpkg != pkg && packages?(dirpkg.name)
                req = make_require(dirpkg)
                dep = pkg.add_require(req)
                if req == dep
                  log.info { "'#{pkg.name}' requires '#{dirpkg.name}'" }
                end
              end
            end
            entry = parent
          end
        end
      end

      # add_dir_to_fs = -> (dir: DirectoryNode) do
      #   if !dir.package
      #     log.warn { "Adding #{dir.path} for dist-package" }
      #     tl_fs_pkg.files << FileEntry.new(dir.path, dir: true)
      #     dir.package = tl_fs_pkg
      #   end
      # end
      #
      # mfdirs = [TEXMFDIR, TEXMFDISTDIR]
      # mfdirs.each do |mf|
      #   tex = @tree[File.join(mf, "tex")]?
      #   if tex && tex.is_a?(DirectoryNode)
      #     mfdirs.each do |dmf|
      #       if mf == dmf
      #         next
      #       end
      #       dir = @tree.mkdir(File.join(dmf, "tex"))
      #       add_dir_to_fs.call(dir)
      #       tex.entries.each do |name, node|
      #         if !node.is_a?(DirectoryNode)
      #           next
      #         end
      #         dir = @tree.mkdir(File.join(dmf, "tex", name))
      #         add_dir_to_fs.call(dir)
      #       end
      #     end
      #   end
      #
      #   fonts = @tree[File.join(mf, "fonts")]?
      #   if fonts && fonts.is_a?(DirectoryNode)
      #     mfdirs.each do |dmf|
      #       if mf == dmf
      #         next
      #       end
      #       dir = @tree.mkdir(File.join(dmf, "fonts"))
      #       add_dir_to_fs.call(dir)
      #       fonts.entries.each do |name, node|
      #         if !node.is_a?(DirectoryNode)
      #           next
      #         end
      #         dir = @tree.mkdir(File.join(dmf, "fonts", name))
      #         add_dir_to_fs.call(dir)
      #       end
      #     end
      #   end
      #
      #   dir = @tree.mkdir(File.join(mf, "doc"))
      #   add_dir_to_fs.call(dir)
      # end

      tl_fs_pkg.files.uniq! do |entry|
        entry.path
      end

      stat = false
      @tree.each_entry_recursive do |entry|
        if !entry.package
          log.error do
            String.build do |io|
              io << "`" << entry.path << "'"
              if entry.is_a?(DirectoryNode)
                io << " (directory)"
              else
                io << " (file)"
              end
              io << " is not contained by a package"
            end
          end
          stat = true
        end
      end
      if stat
        exit 1
      end
    end

    def create_file_tree
      File.open("texlive.filetree", "w") do |x|
        x.print @tree
      end
    end

    def adjust_dependency
      tl_fs_pkg = packages("texlive-filesystem")

      # Add filesystem package as dependency if it contains a file.
      # each_package do |pkg|
      #   if pkg == tl_fs_pkg
      #     next
      #   end
      #   if pkg.files.size > 0
      #     pkg.add_require make_require(tl_fs_pkg)
      #   end
      # end

      deptree = DependencyTree.new(app)
      each_package do |pkg|
        deptree.add(pkg)
      end
      deptree.unresolved_tlpkg_deps.each do |name, set|
        log.warn { "No package provides TL package '#{name}'" }
        set.each do |node|
          log.warn { "   ... required by '#{node.package.name}'" }
        end
      end
      deptree.db.each_value do |node|
        from = node.package
        node.depends.each do |dep|
          from.add_require make_require(dep)
        end
      end

      each_package do |pkg|
        if pkg.files.empty? && pkg.requires.empty?
          log.warn { "#{pkg.name} does not require any other package and does not contain any files" }
        end
      end
    end

    # Make obsolete object from RPM::Package
    def make_obsolete(name : String, epoch : UInt32 | Int32?,
                      version : String, release : String?,
                      flag : RPM::Sense = RPM::Sense::LESS,
                      *, increment_release : Bool = false)
      if release
        d = 0
        i = 0
        if increment_release
          # If release is like "0.1m.mo8", let `d` to `0`, and set
          # incremented release to `1m`.
          release.each_char do |ch|
            {% begin %}
              case ch
                  {% for ch in %w[0 1 2 3 4 5 6 7 8 9] %}
                  when '{{ch.id}}'
                    d = d * 10 + {{ch.id}}
                    i += 1
                  {% end %}
              else
                break
              end
            {% end %}
          end
        end
        if i > 0
          release = "#{d + 1}m"
        else
          release = release.sub(/\.mo\d+/, "")
        end
        v = RPM::Version.new(version, release, epoch)
      else
        flag |= RPM::Sense::EQUAL
        if epoch
          v = RPM::Version.new(version, epoch)
        else
          v = RPM::Version.new(version)
        end
      end
      RPM::Obsolete.new(name, v, flag, nil)
    end

    def make_obsolete(rpmpkg : RPM::Package, f : RPM::Sense = RPM::Sense::LESS,
                      *, increment_release : Bool = true)
      n = rpmpkg.name
      e = rpmpkg[RPM::Tag::Epoch].as(UInt32?)
      v = rpmpkg[RPM::Tag::Version].as(String)
      r = rpmpkg[RPM::Tag::Release].as(String)
      make_obsolete(n, e, v, r, f, increment_release: increment_release)
    end

    def make_obsolete(dep : RPM::Dependency, f : RPM::Sense? = nil,
                      *, increment_release : Bool = false)
      n = dep.name
      e = dep.version.e
      v = dep.version.v
      r = dep.version.r
      f ||= dep.flags
      make_obsolete(n, e, v, r, f, increment_release: increment_release)
    end

    def obsolete_old_packages
      log.info { "Creating obsoletion entries" }
      metadirs = [OLDTEXMFDIR, OLDTEXMFDISTDIR]
      docdirs = metadirs.map { |x| File.join(x, "doc") }
      each_package do |pkg|
        name = pkg.name
        log.info { "Searching obsoletion info for #{name}" }
        pkg.files.each do |entry|
          next if entry.dir?

          # If there is a path matches exactly, use it.
          #
          # For srcfiles and binfiles, only use exact matching.
          #
          installed_pkgs = installed_path_package(entry.path)
          if installed_pkgs.empty? &&
             (entry.tlpdb_tag == TLPDB::Tag::RUNFILES ||
             entry.tlpdb_tag == TLPDB::Tag::DOCFILES)
            basename = File.basename(entry.path)
            paths = installed_file_path(basename)

            # Do not cross-site (for runfiles, exclude `TEXMF/doc`,
            # for docfiles, include only `TEXMF/doc`) files.
            if entry.tlpdb_tag == TLPDB::Tag::RUNFILES
              filter = Proc(String, Bool).new do |path|
                if docdirs.any? { |dir| path.starts_with?(dir) }
                  true
                elsif metadirs.any? { |dir| path.starts_with?(dir) }
                  false
                else
                  true
                end
              end
            else
              filter = Proc(String, Bool).new do |path|
                if docdirs.any? { |dir| path.starts_with?(dir) }
                  false
                else
                  true
                end
              end
            end

            # Compute the path matching score.
            #
            # Score is the number of path elements where same. So, for
            # `/a/b/c/d/e` and `/a/b/x/d/e`, the score will be 2 (`d`
            # and `e`).
            #
            # Use the path with the maximum score.
            #
            pathparts = Path.new(entry.path).parts
            h_map = paths.compact_map do |path|
              if filter.call(path)
                nil
              else
                xparts = Path.new(path).parts
                a = pathparts.reverse_each
                b = xparts.reverse_each
                i = 0
                aa = ""
                bb = ""
                while aa == bb
                  aa = a.next
                  bb = b.next
                  if aa.is_a?(Iterator::Stop) || bb.is_a?(Iterator::Stop)
                    break
                  end
                  i += 1
                end
                {path, i}
              end
            end
            found = nil
            if h_map.size > 0
              found = h_map.max_by do |ent|
                ent[1]
              end
            end
            h_map.each do |ent|
              log.debug do
                String.build do |builder|
                  builder << " --> "
                  if found && ent[0] == found[0]
                    builder << "* "
                  else
                    builder << "  "
                  end
                  builder << ent[0] << " (score: " << ent[1] << ")"
                end
              end
            end
            path = nil

            # For the paths whose score is less than or equal to 3,
            # accept that path only if its basename of ths path is NOT
            # the one of specific one.
            #
            if found
              if found[1] <= 3
                basename = StringCase::Single.new(found[0])
                xpos = 0
                until basename.eof?
                  ch = basename.next_char
                  if ch == '/'
                    xpos = basename.pos
                  end
                end
                basename.pos = xpos
                check_complete_filename = false
                # Begging of filename matching
                StringCase.strcase(case_insensitive: true) do
                  case basename
                  # README and common names
                  when "README", "LICENSE", "LICENCE", "COPYING", "LEGAL",
                       "COPYRIGHT", "CHANGES", "VERSION", "ChangeLog",
                       "INSTALL", "ABOUT", "NEWS", "THANKS", "TODO",
                       "AUTHORS", "BACKLOG", "FONTLOG", "FAQ", "ANNOUNCE",
                       "NOTICE", "HISTORY", "MANIFEST", "00readme",
                       "LISTOFFILES", "LIESMICH", "RELEASE", "CATALOG",
                       "LISEZMOI", "READ.ME", "01install"
                    nil
                    # License filename
                  when "OFL", "GPL", "lppl", "fdl", "GUST-FONT-LICENSE"
                    nil
                    # example
                  when "sample", "example", "exemple"
                    nil
                    # appendix
                  when "appendix"
                    nil
                    # opentype
                  when "opentype", "truetype"
                    nil
                    # logo
                  when "logo"
                    nil
                    # /[0-9][0-9-]*\.ltx.*/
                  when "1", "2", "3", "4", "5", "6", "7", "8", "9", "0"
                    pos = xpos
                    while true
                      case yych
                      when '1', '2', '3', '4', '5', '6', '7', '8', '9', '0',
                           '-'
                      else
                        basename.pos = pos
                        break
                      end
                      pos = basename.pos
                      yych = basename.next_char
                    end
                    StringCase.strcase(case_insensitive: true) do
                      case basename
                      when ".ltx"
                        nil
                      else
                        check_complete_filename = true
                      end
                    end

                    # /(chap|test|fig|note)[0-9]*\.(tex|pdf)/
                  when "chap", "test", "fig", "note"
                    pos = basename.pos
                    yych = basename.next_char
                    while true
                      case yych
                      when '1', '2', '3', '4', '5', '6', '7', '8', '9', '0'
                      else
                        basename.pos = pos
                        break
                      end
                      pos = basename.pos
                      yych = basename.next_char
                    end
                    StringCase.strcase(case_insensitive: true, complete: true) do
                      case basename
                      when ".tex", ".pdf"
                        nil
                      else
                        check_complete_filename = true
                      end
                    end

                    # /cv_template_(en|it|de|pl)\.(tex|pdf)/
                  when "cv_template_"
                    StringCase.strcase(case_insensitive: true) do
                      case basename
                      when "en", "it", "de", "pl"
                        StringCase.strcase(case_insensitive: true, complete: true) do
                          case basename
                          when ".tex", ".pdf"
                            nil
                          else
                            check_complete_filename = true
                          end
                        end
                      else
                        check_complete_filename = true
                      end
                    end
                  else
                    check_complete_filename = true
                  end
                end
                if check_complete_filename
                  # complete file name
                  basename.pos = xpos
                  StringCase.strcase(case_insensitive: true, complete: true) do
                    case basename
                    # for amscls / math-into-latex-4 (template file)
                    when "amsproc.template"
                      nil
                      # amscls (just in source) / amsmath (real class file)
                    when "amsdoc.cls"
                      nil
                      # for lapdf (arcs.pdf is duplicated name used in arcs)
                    when "arcs.pdf"
                      nil
                      # for asymptote
                    when "helix.asy"
                      nil
                      # for pst-marble
                    when "ex5.tex"
                      nil
                      # for texlive-es
                    when "tex-live.css"
                      nil
                      # for aastex
                    when "natnotes.tex"
                      nil
                      # for afparticle
                    when "vitruvian.jpg"
                      nil
                      # for ametstoc
                    when "template.tex"
                      nil
                      # for changebar
                    when "cbtest1.tex"
                      nil
                      # for background
                    when "background.pdf"
                      nil
                      # for classisthesis
                    when "abstract.tex"
                      nil
                      # for ketcindy
                    when "fourier.tex"
                      nil
                      # for fascicules
                    when "tikz.tex"
                      nil
                      # for url
                    when "miscdoc.sty"
                      nil
                      # arabi and poetry are not related.
                    when "poetry.sty"
                      nil
                      # maven
                    when "build.xml"
                      nil
                      # lapdf vs apprends-latex
                    when "curve.tex"
                      nil
                      # beamer (very major package used for presentations)
                    when "beamer"
                      nil
                      # pdfscreen
                    when "pdfscreen"
                      nil
                      # genmisc (plain pkg) / piff (latex pkg)
                    when "time.sty"
                      nil
                      # media9 (as runfiles) / movie15 (as docfiles)
                    when "animation.js"
                      nil
                      # skak (as docfiles) / context (as docfiles)
                    when "demo-symbols.tex"
                      nil
                      # skak (plain pkg) / lambda-lists (latex pkg)
                    when "lambda.sty"
                      nil
                      # latexmk-config file
                    when "latexmkrc"
                      nil
                      # adobemapping (map-info) / bibtexperllibs (script dir)
                    when "ToUnicode"
                      nil
                      # dozenal / misc (seems unrelated)
                    when "gray.tfm"
                      nil
                      # bibtopic / latex-bib[2]-ex / biblatex-philosophy
                    when "articles.bib", "natbib.cfg", "de-examples-dw.bib",
                         "philosophy-examples.bib", "biblatex-examples.bib"
                      nil
                      # language names
                    when "mongolian", "lithuanian", "latin", "german",
                         "italian.pdf", "romanian.pdf", "thai.pdf",
                         "greek-utf8.pdf", "greek-utf8.tex",
                         "bulgarian-utf8.tex", "bulgarian-koi8-r.tex",
                         "maltese-maltese.tex", "maltese-utf8.tex",
                         "ireland.jpg"
                      nil
                      # lshort-*
                    when "custom.tex", "lshort-base.tex", "math.tex",
                         "lshort.sty", "lssym.tex", "mylayout.sty",
                         "spec.tex", "things.tex", "title.tex",
                         "fancyhea.sty", "typeset.tex", "overview.tex"
                      nil
                      # revtex / revtex4
                    when "ltxgrid.pdf", "ltxutil.pdf", "docs.sty",
                         "ltxdocext.pdf", "ltxfront.pdf", "fig_1.eps",
                         "fig_2.eps", "apssamp.tex", "apssamp.bib"
                      nil
                      # generic names used by many packages.
                    when "layout.pdf", "introduction.tex", "index.html",
                         "appendix", "grid.tex", "chart.tex", "manual.pdf",
                         "alea.tex", "fill.tex", "ltxdoc.cfg", "rules.tex",
                         "minimal.tex", "references.bib", "translation.tex",
                         "manifest", "logo.pdf", "guide.pdf", "intro.tex",
                         "preamble.tex", "publish.tex", "test.mf", "at.pdf",
                         "fonts.tex", "preface.tex", "tableaux", "demo.tex",
                         "submit.tex", "user-guide.pdf", "listing.tex",
                         "config.tex", "help.tex", "pgfmanual-en-macros.tex",
                         "frontmatter.tex", "layout.tex", "introduction.pdf",
                         "annexe.tex", "conclusion.tex", "subeqn.tex",
                         "figure1.pdf", "bibliography.bib", "graphics.tex",
                         "metafun.tex", "cover.tex", "doc.pdf", "index.tex",
                         "summary.tex", "charpter1.tex", "references.tex",
                         "implicit.tex", "letter.tex", "cv.tex", "test.pdf",
                         "concepts.tex", "refs.bib", "main.tex", "clean.bat",
                         "ack.tex", "main.pdf", "thesis.bib", "slides.tex",
                         "mybib.bib", "hyphenation.tex", "resume.tex",
                         "biblio.tex", "compilation.tex", "glossary.tex",
                         "getversion.tex", "intro.pdf", "ggamsart.tpl",
                         "Makefile", "GNUmakefile", "index.xml", "demo.pdf",
                         "books.bib", "notes.pdf", "luatex.pdf", "make.bat",
                         "graphics.pdf", "context.html", "bib.bib", "ps.tex",
                         "header.inc", "circle.pdf", "circle.tex", "tds.tex",
                         "rotbox.png", "optional.tex", "source.tex",
                         "symbols.tex", "letter.ist", "style.css", "tex.bib",
                         "guide.tex", "curve.pdf", "geometry.pdf", "test.sh",
                         "generate.sh", "backm.tex", "book.tex", "image.pdf",
                         "eplain.tex", "description.pdf", "polynom.pdf",
                         "vector.pdf", "macros.tex", "Thumbs.db", "bibl.tpl",
                         "thesis.tex", "makedoc.sh", "glyphs.tex", "cat.eps",
                         "guitar.tex", "songbook.pdf", "appendices.tex",
                         "minimal.pdf", "bild.pdf", "list.tex", "block.tex",
                         "contrib.tex", "fontspec.pdf", "header.tex",
                         "denotation.tex", "dtx-style.sty", "invoice.tex",
                         "context.tex", "options.pdf", "intrart.tex",
                         "mathb.tex", "note1b.tex", "data1.dat", "table.tex",
                         "noteslug.tex", "sampart.tex", "minutes.pdf",
                         "franc.sty", "comment.tex", "description.tex",
                         "hyper.pdf", "manual.tex", "tiger.eps", "proba.pdf",
                         "graphic.tex", "article.tex", "publications.pdf",
                         "user-guide.tex", "table.pdf", "textmerg.tex",
                         "tipa.bib", "seminar.con", "perso.ist", "urlbst",
                         "buch.tex"
                      nil
                    else
                      path = found[0]
                    end
                  end
                end
              else
                path = found[0]
              end
            end
            if path
              log.debug { "Using path   '#{path}'" }
              log.debug { "... provides '#{entry.path}'" }
              installed_pkgs = installed_path_package(path)
            end
          end
          installed_pkgs.each do |x, rpmpkg|
            if rpmpkg.name != pkg.name
              if !pkg.obsoletes.any? do |x|
                   if x.responds_to?(:name)
                     x.name == rpmpkg.name
                   else
                     x == rpmpkg.name
                   end
                 end
                obso = make_obsolete(rpmpkg)
                log.info do
                  String.build do |str|
                    str << " ... obsoletes: "
                    str << obso.name << "-" << obso.version.to_vre
                    if path
                      str << " (by file '"
                      str << path
                      str << "' which is assumed to be replaced by '"
                      str << entry.path
                      str << "')"
                    else
                      str << " (by file '"
                      str << entry.path
                      str << "')"
                    end
                  end
                end
                pkg.add_obsolete(obso)
              end
            end
            rpmpkg.obsoletes.each do |obso|
              name = obso.name
              next if name == pkg.name
              next if pkg.obsoletes.any? do |x|
                        if x.responds_to?(:name)
                          x.name == name
                        else
                          x == name
                        end
                      end
              obso = make_obsolete(obso)
              dnevr = obso.to_dnevr
              log.info do
                " ... obsoletes: #{dnevr} (by package #{rpmpkg.name})"
              end
              pkg.add_obsolete(obso)
            end
          end
        end
      end

      # Special obsoletes
      [
        {"texlive-xdvi", "texlive-pxdvik"},
        {"texlive-ptexenc-libs", "texlive-ptexenc"},
        {"texlive-lshort-portuguese", "texlive-texmf-lshort-portuguese"},
        {"texlive-platex", "texlive-texmf-eptex"},
        {"texlive-context-algorithmic", "texlive-texmf-context-algorithmic"},
      ].each do |entry|
        obsolete_installed_pkg_if_not(entry[0], entry[1], log: true)
      rescue InstalledPackageNotFound
      end

      obso_all = RPM::Obsolete.new("texlive-all",
        RPM::Version.new("2010-3m"),
        RPM::Sense::LESS, nil)
      obsolete_if_not("texlive-scheme-full", obso_all, log: true)

      obso_2009_suite = RPM::Obsolete.new("texlive-suite",
        RPM::Version.new("2009-15m"),
        RPM::Sense::LESS, nil)
      obso_2009_texmf = RPM::Obsolete.new("texlive-texmf",
        RPM::Version.new("2009-15m"),
        RPM::Sense::LESS, nil)
      obsolete_if_not("texlive-scheme-full", obso_2009_suite, log: true)
      obsolete_if_not("texlive-scheme-full", obso_2009_texmf, log: true)

      obso_tetex_3 = RPM::Obsolete.new("tetex", RPM::Version.new("3.0"),
        RPM::Sense::LESS | RPM::Sense::EQUAL, nil)
      obsolete_if_not("texlive-scheme-tetex", obso_tetex_3, log: true)

      # Basically, we does not Provide old package names.
      # But tetex will never conflict to any other texlive packages, so
      # added it for mature people who want tetex.
      prov_tetex_3 = RPM::Provide.new("tetex", RPM::Version.new("3.0"),
        RPM::Sense::EQUAL, nil)
      tetex = packages("texlive-scheme-tetex")
      tetex.add_provide(prov_tetex_3)
    end

    def check_obsoletes
      log.info { "Finding packages which won't be obsoleted..." }
      cleanup = packages("cleanup-packages-texlive")
      cset = installed_db.each_package.to_set
      obsoleted_by = {} of String => Set(TLpsrc2spec::Package)
      found_obsoletes = Set(String).new
      each_package do |pkg|
        found_obsoletes.add(pkg.name)
        rem = [] of (String | RPM::Dependency)
        pkg.obsoletes.each do |obso|
          if obso.responds_to?(:name)
            name = obso.name
          else
            name = obso
          end
          found_obsoletes.add(name)
          m = cset.find do |opkg|
            name == opkg.name
          end
          if m.nil?
            ipkg = nil
            # RPM.transaction do |ts|
            begin
              iter = @ts.init_iterator(RPM::DbiTag::Name, name)
              begin
                ipkg = iter.first?
              ensure
                iter.finalize
              end
            end
            if ipkg
              log.warn { "Unexpected obsoletes: #{name} by #{pkg.name}" }
              rem << obso
            end
          end
        end
        rem.each do |obso|
          pkg.obsoletes.delete(obso)
        end
        pkg.obsoletes.each do |obso|
          if obso.responds_to?(:name)
            name = obso.name
          else
            name = obso
          end
          if (entry = obsoleted_by[name]?)
            entry.add(pkg)
          else
            obsoleted_by[name] = Set{pkg}
          end
        end
      end
      installed_db.each_base_package do |pkg|
        if found_obsoletes.includes?(pkg.name)
          next
        end
        obso = make_obsolete(pkg)
        log.warn { "Nothing obsoletes #{obso.name}-#{obso.version.to_vre}" }
        cleanup.add_obsolete(obso)
      end

      log.info { "Reverse obsoletion info" }
      obsoleted_by.each do |name, pkgs|
        if pkgs.size > 0
          log.info { "'#{name}' will be obsoleted by:" }
          pkgs.each do |pkg|
            log.info { " * #{pkg.name}" }
          end
        end
      end

      if (newtljap = packages?("texlive-japanese-recommended"))
        # RPM.transaction do |ts|
        begin
          iter = @ts.init_iterator(RPM::DbiTag::Name, "texlive-japanese-recommended")
          begin
            tljap = iter.first?
            if tljap
              log.info { "'texlive-japanese-recommended' will install:" }
              tljap.requires.each do |req|
                name = req.name
                if (whatobsoletes = obsoleted_by[name]?)
                  whatobsoletes.each do |provider|
                    pname = provider.name
                    if !newtljap.requires.any? do |x|
                         pname == x
                       end
                      log.info { "  * #{pname}" }
                      newtljap.add_require make_require(provider)
                    end
                  end
                elsif (whatprovides = packages?(name))
                  if !newtljap.requires.any? do |x|
                       name == x
                     end
                    log.info { "  * #{name}" }
                    newtljap.add_require make_require(whatprovides)
                  end
                elsif !name.starts_with?("rpmlib")
                  log.warn { "  ... Nothing found which provides #{name}" }
                end
              end
              log.info { "(end)" }
            end
          ensure
            iter.finalize
          end
        end
      end
    end

    def set_master_info
      @master.summary = "The TeX Live text formatting system"
      @master.description = <<-EOD
      The TeX Live software distribution offers a complete TeX system for a
      variety of Unix, Macintosh, Windows and other platforms. It
      encompasses programs for editing, typesetting, previewing and printing
      of TeX documents in many different languages, and a large collection
      of TeX macros and font libraries.

      The distribution includes extensive general documentation about TeX,
      as well as the documentation for the included software packages.
      EOD
      @master.url = "http://www.tug.org/texlive/"
      @master.version = "2019"
      @master.release = "%{momorel}m%{dist}"
      @master.archdep = true

      # Use LPPL as a mandatory license.
      license = Set{"LPPL"}
      io = StringCase::Single.new(64)
      each_package do |pkg|
        pkg.license.each do |lic|
          io.print lic
          io.pos = 0
          StringCase.strcase do
            case io
            when "see \""
              license.add "see \"LICENSE\""
            else
              license.add lic
            end
          end
          io.clear
        end
      end
      @master.license = license.to_a
    end

    def to_path_with_rpm(path : String)
      RPM_PATHMACRO_TABLE.each do |mfpath, repl|
        if path.starts_with?(mfpath)
          path = path.sub(mfpath, repl)
          break
        end
      end
      path
    end

    def adjust_file_path
      log.info { "Converting paths to use RPM macros" }
      each_package do |pkg|
        pkg.files.each do |entry|
          entry.path = to_path_with_rpm(entry.path)
        end
      end
      if !@removing_files.empty?
        tl_fs_pkg = packages?("texlive-filesystem").not_nil!
        has_removing = false
        @removing_files.each do |path|
          node = @tree[path]?
          if !node
            has_removing = true
            node = @tree.insert(path)
          end
        end
        if has_removing
          isc = String.build do |io|
            first = false
            if (script = tl_fs_pkg.install_script)
              if script.size > 0
                io << script
                first = true
              end
            end
            @tree.each_entry_breadth do |entry|
              # removing
              if entry.package.nil?
                parent = entry.parent
                if parent == entry
                  raise "Really remove root-directory?"
                end
                if parent.package.nil?
                  # Already handled parent directory.
                  next
                end
                if first
                  io << "\n"
                  first = false
                end
                io << "%{__rm}"
                if entry.is_a?(DirectoryNode)
                  io << " -rf"
                else
                  io << " -f"
                end
                io << " %{buildroot}" << to_path_with_rpm(entry.path) << "\n"
              end
            end
          end
          tl_fs_pkg.install_script = isc
        end
      end
    end

    def add_mktexlsr_script(target : TLpsrc2spec::Package,
                            filesystem_pkg : TLpsrc2spec::Package)
      if target == filesystem_pkg
        return nil
      end
      if target.name == "kpathsea-bin"
        mktexlsr = true
      else
        mktexlsr = target.tlpdb_pkgs.any? do |tlpkg|
          tlpkg.runfiles.size > 0
        end
      end
      if !mktexlsr
        return nil
      end
      path_i = StringCase::Single.new
      mktexlsrdirs = target.files.compact_map do |entry|
        path_i.clear
        path_i.print entry.path
        path_i.pos = 0
        {% begin %}
          StringCase.strcase do
            case path_i
                {% for mf in TEXMF %}
                  {% var = "%{_" + mf.stringify.downcase + "}" %}
                when {{var}}
                  {{var}}
                {% end %}
            else
              nil
            end
          end
        {% end %}
      end
      mktexlsrdirs.uniq!
      target.post = String.build do |b|
        if (post = target.post)
          b << post
        end
        mktexlsrdirs.each do |path|
          b << "%{_post_mktexlsr " << path << "}\n"
        end
      end
      target.posttrans = String.build do |b|
        if (posttrans = target.posttrans)
          b << posttrans
        end
        mktexlsrdirs.each do |path|
          b << "%{_posttrans_mktexlsr "
          b << path
          b << "}\n"
        end
      end
      nil
    end

    def add_updmap_script(target)
      execs = [] of TLPDB::Execute::AddMap
      target.tlpdb_pkgs.each do |tlpkg|
        tlpkg.executes.each do |ex|
          if ex.is_a?(TLPDB::Execute::AddMap)
            execs << ex
          end
        end
      end
      if execs.size == 0
        return
      end
      # target.install_script = String.build do |b|
      #   if (i = target.install_script)
      #     b << i
      #   end
      #   execs.each do |ex|
      #     b << "%{_updmap_addmap} "
      #     b << ex.maptype.to_s << " "
      #     b << ex.mapfile << "\n"
      #   end
      # end
      target.post = String.build do |b|
        if (i = target.post)
          b << i
        end
        execs.each do |ex|
          b << "%{_post_updmap "
          b << ex.maptype.to_s << " " << ex.mapfile << "}\n"
        end
      end
      target.postun = String.build do |b|
        if (i = target.postun)
          b << i
        end
        execs.each do |ex|
          b << "%{_postun_updmap "
          b << ex.maptype.to_s << " " << ex.mapfile << "}\n"
        end
      end
      target.posttrans = String.build do |b|
        if (i = target.posttrans)
          b << i
        end
        execs.each do |ex|
          b << "%{_posttrans_updmap "
          b << ex.maptype.to_s << " " << ex.mapfile << "}\n"
        end
      end
    end

    def add_format_script(target)
      execs = [] of TLPDB::Execute::AddFormat
      target.tlpdb_pkgs.each do |tlpkg|
        tlpkg.executes.each do |ex|
          if ex.is_a?(TLPDB::Execute::AddFormat)
            execs << ex
          end
        end
      end
      # if execs.any? { |exe| exe.mode == "disabled" }
      #   target.install_script = String.build do |str|
      #     if target.install_script
      #       str << target.install_script
      #     end
      #     execs.each do |exe|
      #       if exe.mode == "disabled"
      #         str << "%{_enable_format " << exe.name << "}\n"
      #       end
      #     end
      #   end
      # end
    end

    def add_script
      fspkg = packages("texlive-filesystem")
      each_package do |pkg|
        add_mktexlsr_script(pkg, fspkg)
        add_updmap_script(pkg)
        add_format_script(pkg)
      end
    end

    def collect
      create_package_from_tlpdb
      create_file_entries
      adjust_dependency
      create_file_tree
      obsolete_old_packages
      check_obsoletes
      adjust_file_path
      add_script
      set_master_info
    end

    def master_package
      @master
    end
  end
end
