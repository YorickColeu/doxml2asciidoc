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
                      if param[:declname].eql? name.text
                        # Do the remainder of the mappings
                        param[:direction] = parameteritem.at('./parameternamelist/parametername')['direction']
                        param[:description] = parameteritem.at('./parameterdescription/para').text
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
    hsh[:children] = []
    hsh[:name] = ""
    hsh[:name] = section.xpath("./compoundname").text

    ret = parse_sectiondef_func section.xpath("./sectiondef")

    if !section.xpath("./innergroup").nil?
      section.xpath("./innergroup").each do |innergroup|
        hsh[:children].push :name => innergroup.text
      end
    else
      hsh[:children] = nil
    end

    if ret[:functions].length > 0
      hsh[:functions] = ret[:functions]
    end
    groups.push hsh

    groups
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

    def recursive_group tree, node_list, index
      if !node_list.nil?
        index += 1
        node_list.each do |node|
          @str += "="  + "="*index + " " + tree[node][:name] + "\n"
          if !tree[node][:functions].nil?
          @str += "==" + "="*index + " Functions\n"
           
          @str += "\n"
            tree[node][:functions].each do |func|
              single_function func, index
            end
          end
          @str += "\n"
          recursive_group tree, tree[node][:child_id], index
        end
      end
    end

    def generate

      @str = "= #{@name} API Documentation\n"
      @str += ":source-highlighter: coderay\n"
      @str += ":toc: left\n"
      @str += ":toclevels: 4\n"
      @str += "\n"

      #output_typedefs


      output_page

      # Create a group list with indexes
      group_list = []
      i = 0
      @files.each do |hsh|
        if !hsh[:groups].nil?
          hsh[:groups].each do |group|
            group[:id] = i
            i += 1
            group_list.push group
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

      # Add to tree the group names and their functions
      tree.each do |group|
        if !group[0].nil?
          group[1][:name]      = group_list.find {|x| x[:id] == group[0]}[:name]
          group[1][:functions] = group_list.find {|x| x[:id] == group[0]}[:functions]
        end
      end

      # Parse the node tree and build adoc
      index = 0
      recursive_group tree, tree[nil][:child_id], index

      # Print the rest of the document

      output_enums

      @str += "== Functions\n"
      @str += "\n"

      @files.each do |hsh|
        hsh[:functions].each do |func|
          single_function func
        end
      end
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

    def output_page
      pages = []
      @files.each do |hsh|
        if hsh.has_key? :pages
          hsh[:pages].each do |page|
            pages << page
          end
        end
      end

      if pages.length > 0
        pages.each do |page|
          single_page page
        end
        @str += "\n"
      end
    end

    def single_page page
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
          header_index = "="
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

    def single_enum enum
      @str += "=== #{enum[:name]}\n"
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
      @str += "#{func[:definition]} #{func[:argsstring]}\n"
      @str += "----\n"
      @str += "\n"

      @str += "| Parameters\n"
      @str += "|\n"
      func[:params].each do |param|
        @str += "#{parameter_direction_string param}`#{param[:type]} #{param[:declname]}`::\n"
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
