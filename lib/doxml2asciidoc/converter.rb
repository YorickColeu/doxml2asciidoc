require 'fileutils'

module Doxml2AsciiDoc
class Converter

  @@verbose = false

  def initialize opts = {}
    @root = nil
  end

  def process root
    @root = root

    str = convert

    @root = nil

    str
  end

  def verbose msg
    if @@verbose
      puts msg
    end
  end

  def convert
    verbose "Converting"

    hsh = parse @root
    ad = AsciidocOutput.new hsh
    ad.generate
  end

  def self.parse_file infile
    str = ::IO.read infile
    xmldoc = ::Nokogiri::XML::Document.parse str
    converter = Converter.new xmldoc
    converter.verbose "Parsing input file: #{infile}"
    converter.parse(xmldoc.root)
  end

  # The xml file has been converted to Nokogiri XML Document
  # Different processing occurs depending on copound kind
  def parse root
    @root = root
    hsh =  nil
    if @root.name.eql? "doxygenindex"
      verbose "Input root is DoxygenIndex"
      hsh = parse_doxygenindex @root
    elsif @root.name.eql? "doxygen"
      verbose "Input root is Doxygen"
      compound_def = @root.at_xpath('//compounddef')
      case compound_def['kind']
      when 'file'
        hsh = parse_doxygenfile @root
      when 'page'
        hsh = parse_doxygenfile_page @root
      when 'group'
        hsh = parse_doxygenfile_group @root
      when 'struct'
        hsh = parse_doxygenfile_struct @root
      when 'union'
        hsh = parse_doxygenfile_union @root
      else
        raise "Unknown/unhandled compound_def " + compound_def['kind']
      end
    else
      raise "Unhandled/Unknown root element: " + @root.name
    end

    hsh
  end

  # Assume the input doc rootelement is 'doxygenindex'
  def parse_doxygenindex root

    hsh = {:name => "Index",
           :files => [],
    }

    root.xpath('//compound').each do |compound|

      xmldir = ::FileUtils.pwd
      filename = "#{compound['refid']}.xml"
      filepath = File.join xmldir, filename

      verbose "Parsing compound... Kind: " + compound['kind']

      case compound['kind']
      when 'file'
        h = Converter.parse_file filepath
        hsh[:files] << h
      when 'page'
        h = Converter.parse_file filepath
        hsh[:files] << h
      when 'group'
        h = Converter.parse_file filepath
        hsh[:files] << h
      when 'struct'
        h = Converter.parse_file filepath
        hsh[:files] << h
      when 'union'
        h = Converter.parse_file filepath
        hsh[:files] << h
      when 'dir'
        # Silently ignore this compound - we dont care about it.
      else
        $stderr.puts "Unhandled doxygenindex compound kind: " + compound['kind']
      end
    end

    hsh
  end

  def parse_doxygenfile root
    compound = root.at_xpath '//compounddef'

    hsh = {:name => compound.element_children.at_xpath('//compoundname').text,
           :id => compound['id'],
           :language => compound['language'],
           :functions => [],
           :enums => [],
           :typedefs => [],
           :vars => []
          }

    compound.xpath('./sectiondef').each do |section|
      verbose "Parsing sectiondef kind " + section['kind']
      case section['kind']
      when 'define'
        parse_sectiondef_define section
      when 'func'
       ret = parse_sectiondef_func section
       hsh[:functions].concat ret[:functions]
      when 'typedef'
        ret = parse_sectiondef_typedef(section)
        hsh[:typedefs].concat(ret)
      when 'enum'
        ret = parse_sectiondef_enum(section)
        hsh[:enums].concat(ret)
      when 'var'
        ret = parse_sectiondef_var(section)
        hsh[:vars].concat(ret)
      else
        raise "Unhandled section kind " + section['kind']
      end
    end

    hsh
  end

  def parse_doxygenfile_page root
    compound = root.at_xpath '//compounddef'

    hsh = {:name => compound.element_children.at_xpath('//compoundname').text,
           :id => compound['id'],
           :language => compound['language'],
           :functions => [],
           :enums => [],
           :typedefs => [],
           :vars => [],
           :pages => []
          }
    compound.xpath('./detaileddescription').each do |section|
      ret = parse_sectiondef_page(section)
      hsh[:pages].concat(ret)
    end

    hsh
  end

  def parse_doxygenfile_group root
    compound = root.at_xpath '//compounddef'

    hsh = {:name => compound.element_children.at_xpath('//compoundname').text,
           :id => compound['id'],
           :language => compound['language'],
           :functions => [],
           :enums => [],
           :typedefs => [],
           :vars => [],
           :pages => [],
           :groups => []
          }
    
    ret = parse_sectiondef_group(compound)
    hsh[:groups].concat(ret)

    hsh
  end

  def parse_doxygenfile_struct root
    compound = root.at_xpath '//compounddef'

    hsh = {:name => compound.element_children.at_xpath('//compoundname').text,
           :id => compound['id'],
           :language => compound['language'],
           :structs => []
          }

    compound.xpath('./sectiondef').each do |section|
      verbose "Parsing sectiondef kind " + section['kind']
      case section['kind']
      when 'public-attrib'
        ret = parse_sectiondef_union_or_struct(section)
        ret[:name] = compound.element_children.at_xpath('//compoundname').text
        ret[:type] = "struct"
        ret[:briefdescription] = compound.xpath('./briefdescription').text
        ret_array = []
        ret_array.push ret

        hsh[:structs].concat(ret_array)
      else
        raise "Unhandled section kind " + section['kind']
      end
    end
    
    hsh
  end

  def parse_doxygenfile_union root
    compound = root.at_xpath '//compounddef'

    hsh = {:name => compound.element_children.at_xpath('//compoundname').text,
           :id => compound['id'],
           :language => compound['language'],
           :unions => []
          }

    compound.xpath('./sectiondef').each do |section|
      verbose "Parsing sectiondef kind " + section['kind']
      case section['kind']
      when 'public-attrib'
        ret = parse_sectiondef_union_or_struct(section)
        ret[:name] = compound.element_children.at_xpath('//compoundname').text
        ret[:type] = "union"
        ret[:briefdescription] = compound.xpath('./briefdescription').text
        ret_array = []
        ret_array.push ret

        hsh[:unions].concat(ret_array)
      else
        raise "Unhandled section kind " + section['kind']
      end
    end

    hsh
  end

  def parse_sectiondef_define section
    # TODO: Implement me
    $stderr.puts "WARNING: sectiondef define not implemented."
    []
  end

  def parse_sectiondef_var section
    # TODO: implement me
    $stderr.puts "WARNING: sectiondef var not implemented."
    []
  end

  def parse_sectiondef_typedef section
    typedefs = []

    section.xpath('./memberdef').each do |member|
      case member['kind']
      when 'typedef'
        hsh = {}
        hsh[:name] = member.at_xpath('./name').text
        hsh[:type] = member.at_xpath('./type').text
        detail = member.at_xpath('./detaileddescription')
        if detail
          hsh[:doc] = detail.text
        end
        typedefs << hsh
      else
        raise "member kind not typedef in sectiondef typedef: #{meber['kind']}"
      end
    end

    typedefs
  end

  def parse_sectiondef_enum section
    enums = []
    section.xpath('./memberdef').each do |member|
      case member['kind']
      when 'enum'
        hsh = {}
        hsh[:name] = member.at_xpath('./name').text

        brief = member.at_xpath('./briefdescription/para')
        if brief
          hsh[:doc] = brief.text
        end

        hsh[:enums] = []
        member.xpath('./enumvalue').each do |enum|
          e = {}
          e[:name] = enum.at_xpath('./name').text
          # Get the first para in briefdescription
          brief = enum.at_xpath('./briefdescription/para')
          if brief
            # brief is contained in one or more para children?
            e[:doc] = brief.text
          end
          hsh[:enums] << e
        end
        enums << hsh
      else
        raise "member kind not enum in sectiondef enum: (#{member['kind']}"
      end
    end

    enums
  end

  def parse_sectiondef_func section
    functions = []
    section.xpath('./memberdef').each do |member|
      case member['kind']
      when 'function'
        hsh = {}
        hsh[:function_name] = member.at_xpath('./name').text
        hsh[:return_type] = member.at_xpath('./type').text
        hsh[:definition] = member.at_xpath('./definition').text
        hsh[:argsstring] = member.at_xpath('./argsstring').text

        params = []
        member.xpath('./param').each do |param|
          t = param.at_xpath('./type')
          d = param.at_xpath('./declname')
          t ||= t.text
          d ||= t.text
          if t.nil? || d.nil?
            $stdout.puts "WARNING: Function #{hsh[:function_name]} para type: #{t}, para decl: #{d}"
          end
          param = {:type => t,
                   :declname => d,
                  }
          params.push param
        end
        hsh[:params] = params
        hsh[:return] = []
        detail = member.at_xpath('./detaileddescription')
        if detail
          hsh[:detail] = []
          #detail contains one or more <para></para> entries
          # The first entry contains the long ass description, IF IT EXISTS
          detail.xpath('./para').each do |para|
            if para.element_children.size == 0
              # Detailed description
              hsh[:detail].push :type => :text, :value => para.text
            else
              # Iterate all children of para
              para.children.each do |child|
                if child.text?
                  hsh[:detail].push :type => :text, :value => child.text

                elsif child.element? and child.name.eql? "programlisting"
                  # CODE!
                  codeblock = ""
                  child.children.each do |codeline|
                    line = ""
                    codeline.children.each do |e|
                      line = parse_codeline e, line
                    end
                    if not line.empty?
                      line += "\n"
                    end
                    codeblock += line
                  end
                  hsh[:detail].push :type => :code, :value => codeblock

                elsif child.element? and child.name.eql? "itemizedlist"
                  listitems = child.xpath('./listitem')
                  next if listitems.nil?

                  list = []
                  listitems.each do |item|
                    list << item.at_xpath('./para').text
                  end
                  hsh[:detail].push :type => :list, :value => list

                elsif child.element? and child.name.eql? "parameterlist"
                  # Parameters
                  parameters = child.xpath('./parameteritem')
                  next if parameters.nil?

                  parameters.each do |parameteritem|
                    name = parameteritem.at('./parameternamelist/parametername')
                    next if name.nil?
                    next if name.text.empty?

                    # Find the associated entry in the param list
                    hsh[:params].each do |param|
                      if param[:declname].class.name.eql?  "Nokogiri::XML::Element"
                        if param[:declname].text.to_s.strip.eql? name.text.to_s.strip
                          # Do the remainder of the mappings
                          param[:direction] = parameteritem.at('./parameternamelist/parametername')['direction']
                          param[:description] = parameteritem.at('./parameterdescription/para').text
                        end
                      end
                    end
                  end

                elsif child.element? and child.name.eql? 'simplesect'
                  case child['kind']
                  when "return"
                    hsh[:return] <<  child.text
                  else
                    $stderr.puts 'detailed description -> simplesect kind not handled: ' + child['kind']
                  end

                else
                  $stderr.puts "detailed description parameter child not handled: " + child.name
                end
              end

            end
          end
        end

        hsh[:brief] = member.at_xpath('./briefdescription').text

        functions.push hsh
      else
        raise "Unhandled sectiondef->memberdef kind " + member['kind']
      end
    end

    {:functions => functions}
  end

  def parse_sectiondef_page section
    pages = []
    hsh = {}
    hsh[:section] = []


    section.xpath("//*").each do |section_element|
      if section_element.node_name.to_s == 'para'
        if section_element.element_children.size == 0 and section_element.parent.name != "listitem"
          # Detailed description
          hsh[:section].push :type => :text, :value => section_element.text
        else
          # Iterate all children of para
          section_element.children.each do |child|
            if child.element? and child.name.eql? "programlisting"
              # CODE!
              codeblock = ""
              child.children.each do |codeline|
                line = ""
                codeline.children.each do |e|
                  line = parse_codeline e, line
                end
                if not line.empty?
                  line += "\n"
                end
                codeblock += line
              end
              hsh[:section].push :type => :code, :value => codeblock
            elsif child.element? and child.name.eql? "itemizedlist"
              listitems = child.xpath('./listitem')
              next if listitems.nil?

              list = []
              listitems.each do |item|
                list << item.at_xpath('./para').text
              end
              hsh[:section].push :type => :list, :value => list
            else
              $stderr.puts "detailed description parameter child not handled: " + child.name
            end
          end
        end
      elsif section_element.node_name.to_s == 'title'
        # Get header index
        if section_element.parent.name.include? "compounddef"
          hsh[:section].push :type => :title, :value => section_element.text, :index => 0
        elsif section_element.parent.name.include? "sect"
          hsh[:section].push :type => :title, :value => section_element.text, :index => section_element.parent.name[-1].to_i
        end
      end

    end

    pages.push hsh
    pages
  end

  # Parse xml structures: Get list of groups with their children
  def parse_sectiondef_group section
    groups = []
    hsh = {}
    hsh[:children]       = []
    hsh[:functions]      = []
    hsh[:pages]          = []
    hsh[:typedefs]       = []
    hsh[:enums]          = []
    hsh[:structs]        = []
    hsh[:innerclasses]   = []
    hsh[:vars]           = []
    hsh[:name] = ""
    hsh[:name] = section.xpath("./title").text

    section.xpath("./innerclass").each do |innerclass|
      verbose "Parsing sectiondef prot: " + innerclass['prot'].to_s
      hsh[:innerclasses].push :refid => innerclass['refid']
    end

    section.xpath("./sectiondef").each do |section|
      verbose "Parsing sectiondef kind " + section['kind']
      case section['kind']
      when 'define'
        parse_sectiondef_define section
      when 'func'
        ret = parse_sectiondef_func section
        hsh[:functions].concat ret[:functions]
      when 'page'
        ret = parse_sectiondef_page section
        hsh[:pages].concat ret[:pages]
      when 'typedef'
        ret = parse_sectiondef_typedef(section)
        hsh[:typedefs].concat(ret)
      when 'enum'
        ret = parse_sectiondef_enum(section)
        hsh[:enums].concat(ret)
      when 'struct'
        ret = parse_sectiondef_struct(section)
        hsh[:structs].concat(ret)
      when 'var'
        ret = parse_sectiondef_var(section)
        hsh[:vars].concat(ret)
      else
        raise "Unhandled section kind " + section['kind']
      end
    end

    if !section.xpath("./innergroup").nil?
      section.xpath("./innergroup").each do |innergroup|
        hsh[:children].push :name => innergroup.text
      end
    else
      hsh[:children] = nil
    end

    groups.push hsh

    groups
  end

  # Parse xml structures: Get list of groups with their children
  def parse_sectiondef_union_or_struct section
    union_or_struct = []
    hsh = {}
    hsh[:variables] = []
    section.xpath('./memberdef').each do |member|
      case member['kind']
      when 'variable'
        variable = {}
        variable[:type]                = member.at_xpath('./type').text
        variable[:argsstring]          = member.at_xpath('./argsstring').text
        variable[:name]                = member.at_xpath('./name').text
        variable[:briefdescription]    = member.at_xpath('./briefdescription').text
        variable[:detaileddescription] = member.at_xpath('./detaileddescription').text
        variable[:inbodydescription]   = member.at_xpath('./inbodydescription').text

        hsh[:variables].push variable
      end
    end
    hsh
  end
  
  def parse_codeline element, line
    if element.text?
      line += element.text
    elsif element.element? and element.name.eql? "sp"
      line += " "
    elsif element.element? and element.name.eql? "highlight"
      element.children.each do |c|
        line = parse_codeline c, line
      end
    else
      $stderr.puts "Codeline element not handled: " + e.name
    end
    line
  end

end

  class AsciidocOutput
    def initialize hsh = {}
      @str = ""
      @files = []
      @name = hsh[:name]

      if hsh.has_key?(:files)
        @files = hsh[:files]
      else
        @files << hsh
      end
    end

    def recursive_group tree, node_list, index, union_list, struct_list
      if !node_list.nil?
        index += 1
        node_list.each do |node|
          @str += "="  + "="*index + " " + tree[node][:name] + "\n"
          if !tree[node][:pages].empty?
            tree[node][:pages].each do |page|
              single_page page
            end
          end
          if !tree[node][:functions].empty?
            @str += "==" + "="*index + " Functions\n"
            @str += "\n"
            tree[node][:functions].each do |func|
              single_function func, index+1
            end
          end
          if !tree[node][:enums].empty?
            @str += "==" + "="*index + " Enums\n"
            @str += "\n"
            tree[node][:enums].each do |enum|
              single_enum enum, index+1
            end
          end
          if !tree[node][:structs].empty?
            @str += "==" + "="*index + " Structs\n"
            tree[node][:structs].each do |struct|
              @str += "\n"
              @str += "===" + "="*index + " #{struct[:name]}\n"
              @str += "\n"
              @str += "[cols='h,5a']\n"
              @str += "|===\n"
              @str += "| Description\n"
              @str += "| #{struct[:briefdescription]}\n"
              @str += "\n"

              @str += "| Signature \n"
              @str += "|\n"
              @str += "[source,C]\n"
              @str += "----\n"
              recursive_struct_or_union struct, 0, union_list, struct_list
              @str += "----\n"
              @str += "|===\n"
              
              @str += "\n"
            end
          end
          @str += "\n"
          recursive_group tree, tree[node][:child_id], index, union_list, struct_list
        end
      end
    end

    def recursive_struct_or_union struct_or_union, index, union_list, struct_list, variable_name=nil
      ret = {}

      if struct_or_union[:type].eql? "union"
        # This component is a union
        @str += "   "*index + "union\n"
        @str += "   "*index + "{\n"
      elsif struct_or_union[:type].eql? "struct"
        # This component is a structure
        @str += "   "*index + "struct "
        if !struct_or_union[:name].include? ".__unnamed__."
          @str += "#{struct_or_union[:name]}"
        end
        @str += "\n"
        @str += "   "*index + "{\n"
      end
      # Go through components
      struct_or_union[:variables].each do |variable|
        # If this is a struct or enum: recursive_struct_or_union -> 
        if variable[:type].include? "union "
          # Find it on union_list          
          recursive_struct_or_union union_list.find {|x| x[:name].include? variable[:type].gsub("union ", "").split('::')[0]}, index+1, union_list, struct_list
        elsif variable[:type].include? "struct "
          # Find it on struct_list
          struct_list.select {|x| x[:name].include? variable[:type].gsub("struct ", "").split('::')[0]+"."}.each do |struct|
            if struct[:name].split('.')[-1].to_s.eql? variable[:name].to_s
              recursive_struct_or_union struct, index+1, union_list, struct_list, variable[:name]
            end
          end
        else
          # If this is variable or enum: simply print its info
          if !variable[:detaileddescription].strip.empty?
            @str += "   "*(index+1) + "/** #{variable[:name]}#{variable[:detaileddescription]}\n"
            @str += "   "*(index+1) + "*/\n"
          end
          @str += "   "*(index+1) + "#{variable[:type]} #{variable[:name]}"
          if !variable[:argsstring].empty?
            @str += "#{variable[:argsstring]}"
          end
          @str += ";\n"
        end
      end
      @str += "   "*index + "}"
      if struct_or_union[:type].eql? "union"
        if !struct_or_union[:name].include? ".__unnamed__"
          @str += "   "*(index+1) + "#{struct_or_union[:name]}"
        end
      elsif struct_or_union[:type].eql? "struct"
        if !variable_name.nil?
          @str += "#{variable_name}"
        end
      end
      @str += ";"
      @str += "\n"
    end

    def generate

      @str = "= #{@name} API Documentation\n"
      @str += ":source-highlighter: coderay\n"
      @str += ":toc: left\n"
      @str += ":toclevels: 4\n"
      @str += "\n"

      #output_typedefs

      # Print README
      @files.each do |hsh|
        if !hsh.nil?
          if hsh.has_key? :pages and hsh[:name].eql?("md_README")
            hsh[:pages].each do |page|
              single_page page
            end
          end
        end
      end

      # Create a group list
      group_list = []
      i = 0
      @files.each do |hsh|
        if !hsh.nil?
          if !hsh[:groups].nil?
            hsh[:groups].each do |group|
              # Add indexes
              group[:id] = i
              i += 1
              group_list.push group
            end
          end
        end
      end

      # Create a struct list
      struct_list = []
      @files.each do |hsh|
        if !hsh.nil?
          if !hsh[:structs].nil?
            hsh[:structs].each do |struct|
              struct_list.push struct
            end
          end
        end
      end

      # Create a union list
      union_list = []
      i = 0
      @files.each do |hsh|
        if !hsh.nil?
          if !hsh[:unions].nil?
            hsh[:unions].each do |union|
              union_list.push union
            end
          end
        end
      end

      # The following list helps knowing if structs has already been mapped to groups
      list_filled_structs = []
      @files.each do |hsh|
        if !hsh.nil?
          if hsh.has_key? :pages
            hsh[:pages].each do |page|
              # The following code parse the page ID name to extract groupname
              intermediate_str = hsh[:id][7..-1][/^([a-zA-Z0-9]+([_]{2,}[[a-zA-Z0-9]]*)+)/,1].to_s
              groupname = intermediate_str.gsub("__", "_")
              pagename  = hsh[:id][7..-1].gsub(intermediate_str+"_", "")
              if group_list.find {|x| x[:name].casecmp(groupname) == 0}
                group_list.find {|x| x[:name].casecmp(groupname) == 0}[:pages].push page
              end
            end
          end
          if hsh.has_key? :structs
            hsh[:structs].each do |struct|
              group_list.each do |group|
                # If current group isn't refered in list_filled_structs: Add it
                if !list_filled_structs.find {|x| x[:groupname].eql? group[:name]}
                  list_filled_structs.push :groupname => group[:name], :structlist => []
                end
                if !group[:innerclasses].empty?
                  group[:innerclasses].each do |innerclass|
                    if innerclass[:refid].start_with?('struct')
                      # Parse it to get the struct name
                      intermediate_str = innerclass[:refid][6..-1][/^([a-zA-Z0-9]+([_]{2,}[[a-zA-Z0-9]]*)+)/,1].to_s
                      structname = intermediate_str.gsub("__", "_")
                      if group_list.find {|x| x[:name].casecmp(group[:name]) == 0}
                        # Check if we already added this struct to the group
                        if !list_filled_structs.find {|x| x[:groupname].eql? group[:name]}[:structlist].find {|x| x.eql? struct_list.find {|x| x[:name].casecmp(structname) == 0}[:name]}
                          group_list.find {|x| x[:name].casecmp(group[:name]) == 0}[:structs].push struct_list.find {|x| x[:name].casecmp(structname) == 0}
                          list_filled_structs.find {|x| x[:groupname].eql? group[:name]}[:structlist].push struct_list.find {|x| x[:name].casecmp(structname) == 0}[:name]
                        end
                      end
                    end
                  end
                  if group[:innerclasses].find {|x| x[:refid].casecmp(struct[:id]) == 0}
                    group[:structs].push struct
                  end
                else
                end
              end
            end
          end
        end
      end

      # Create child ID list for parents
      group_list.each do |group|
        if !group[:children].nil?
          group[:child_id] = []
          group[:children].each do |child|
            # Search list for child ID
            group[:child_id].push group_list.find {|x| x[:name].casecmp(child[:name]) == 0}[:id]
          end
          group.tap { |hs| hs.delete(:children) }
        end
      end

      # Set parent IDs
      group_list.each do |node|
        if !node[:child_id].nil?
          node[:child_id].each do |child_id|
            # Find associated group and add parent ID 
            group_list.find {|x| x[:id] == child_id}[:parent_id] = node[:id]
          end
        end
      end

      # Find groups that have no perents and set it to nil
      group_list.each do |node|
        if node[:parent_id].nil?
          node[:parent_id] = nil
        end
      end

      # Set a node tree
      tree = {}
      group_list.each do |node|
        current          = tree.fetch(node[:id])        { |key| tree[key]   = {} }
        parent           = tree.fetch(node[:parent_id]) { |key| tree[key]   = {} }
        siblings         = parent.fetch(:child_id)      { |key| parent[key] = [] }
        current[:parent] = node[:parent_id]
        siblings.push(node[:id])
      end

      # Add to tree the group names and their components
      tree.each do |group|
        if !group[0].nil?
          group[1][:name]      = group_list.find {|x| x[:id] == group[0]}[:name]
          group[1][:pages]     = group_list.find {|x| x[:id] == group[0]}[:pages]
          group[1][:functions] = group_list.find {|x| x[:id] == group[0]}[:functions]
          group[1][:enums]     = group_list.find {|x| x[:id] == group[0]}[:enums]
          group[1][:structs]   = group_list.find {|x| x[:id] == group[0]}[:structs]
          group[1][:unions]    = group_list.find {|x| x[:id] == group[0]}[:unions]
          group[1][:typedefs]  = group_list.find {|x| x[:id] == group[0]}[:typedefs]
        end
      end

      # Parse the node tree and build adoc
      index = 0
      if !tree.empty?
        recursive_group tree, tree[nil][:child_id], index, union_list, struct_list
      end

      # End of document
      @str += "\n"
    end

    def output_typedefs
      typedefs = []
      @files.each do |hsh|
        if hsh.has_key? :typedefs
          hsh[:typedefs].each do |typedef|
            typedefs << typedef
          end
        end
      end
      if typedefs.length > 0
        @str += "== Typedefs\n"
        @str += "\n"
        typedefs.each do |typedef|
          single_typedef typedef
        end
        @str += "\n"
      end
    end

    def output_enums
      @str += "== Enums\n"
      @str += "\n"
      @files.each do |hsh|
        hsh[:enums].each do |enum|
          single_enum enum
        end
      end
      @str += "\n"
    end

    def single_page page, index=1
      page[:section].each do |section|
        if section[:type] == :code
          if section[:value].include? "[ditaa]"
            @str += "#{section[:value]}\n"
          else
            @str += "----\n"
            @str += "#{section[:value]}\n"
            @str += "----\n"
          end
        elsif section[:type] == :title
          header_index = "=" + "="*index
          for i in 0..section[:index]
            header_index += '='
          end
          @str += "\n"
          @str += header_index + " #{section[:value]}\n"
        elsif section[:type] == :text
          @str += "#{section[:value]}\n\n"
        elsif section[:type] == :list
          @str += "\n"
          section[:value].each do |txt|
            @str += " * #{txt}\n"
          end
          @str += "\n\n"
        end
      end
    end

    def single_typedef typedef
      @str += "=== #{typedef[:name]}\n"
      @str += "\n"
      @str += "[horizontal]\n"
      @str += "#{typedef[:type]} -> #{typedef[:name]}:: #{typedef[:doc]}\n"
    end

    def single_enum enum, index=1
      @str += "=="  + "="*index + " " + "#{enum[:name]}\n"
      @str += "\n"
      @str += enum[:doc] if enum[:doc]
      @str += "\n"
      @str += "[horizontal]\n"
      enum[:enums].each do |e|
        doc = e[:doc]
        doc ||= "No documentation entry."
        @str += "#{e[:name]}:: #{doc}\n"
      end
      @str += "\n"
    end

    def single_function func, index=1

      @str += "=="  + "="*index + " " + func[:function_name] + "\n"
      @str += "\n"
      @str += "[cols='h,5a']\n"
      @str += "|===\n"
      @str += "| Description\n"
      @str += "| #{func[:brief]}\n"
      @str += "\n"

      @str += "| Signature \n"
      @str += "|\n"
      @str += "[source,C]\n"
      @str += "----\n"
      @str += "#{func[:definition]} #{func[:argsstring]}\n\n"
      @str += "----\n"
      @str += "\n"

      @str += "| Parameters\n"
      @str += "|\n"
      func[:params].each do |param|
        if param[:type].is_a? String
          type = "#{param[:type]}"
        else
          type = "#{param[:type].text}"
        end

        if param[:declname].is_a? String
          declname = ""
        else
          declname = " #{param[:declname].text}"
        end
        @str += "#{parameter_direction_string param}`#{type}#{declname}`::\n"
        @str += "#{param[:description]}\n"
      end
      @str += "\n"

      if func[:return].length > 0
        @str += "| Return\n"
        @str += "| "
        func[:return].each do |ret|
          @str += "* #{ret} \n"
        end
        @str += "\n"
      end

      # All entries have one '\n' :text entry - Ignore this section if so.
      if func[:detail].length > 2
        @str += "|===\n"
        @str += "====\n"
        @str += "*Details / Examples:* \n"
        @str += "\n"
        # @str += "|\n"
        func[:detail].each do |detail|
          if detail[:type] == :code
            @str += "\n....\n"
            @str += "#{detail[:value]}\n"
            @str += "....\n"
          elsif detail[:type] == :text
            @str += "#{detail[:value]}\n"
          elsif detail[:type] == :list
            @str += "\n"
            detail[:value].each do |txt|
              @str += " * #{txt}\n"
            end
            @str += "\n\n"
          end
        end
        @str += "====\n"
        @str += "\n"
      else
        @str += "|===\n"
        @str += "\n"
      end

    end

    def parameter_direction_string param
      if param[:direction]
        "*#{param[:direction]}* "
      else
        ""
      end
    end
  end # AsciidocOutput

end
