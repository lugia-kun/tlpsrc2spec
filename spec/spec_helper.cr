require "spec"
require "../src/tlpsrc2spec"

module EnumCompare
  macro enum_compare(enum_to_test, enum_for_reference, prefix = nil)
    describe "{{enum_to_test}}" do
      {{enum_to_test}}.each do |x|
        n = x.to_s.downcase.gsub("_", "")
        t = {{enum_for_reference}}.each do |y|
          ys = y.to_s
          if {{prefix}}
            ys = ys.gsub({{prefix}}, "")
          end
          ys = ys.downcase.gsub("_", "")
          break y if ys == n
          nil
        end
        it "has Name #{x} valid?" do
          t.should_not be_nil
        end
        if t
          it "has #{x} == #{t}" do
            tt = t.as({{enum_for_reference}})
            x.value.should eq(tt.value)
          end
          {% if enum_for_reference.resolve.class.has_method?(:get_name) %}
            name = {{enum_for_reference}}.get_name(t.as({{enum_for_reference}}))
            if name != "(unknown)"
              if x.to_s != name
                pending "has Name #{x} tested, but differs from library's conversion, #{name}" do
                  x.to_s.should eq(name)
                end
              end
            else
              pending "has name #{x} tested, but not in the library" do
              end
            end
          {% end %}
        end
      end
    end
  end
end
