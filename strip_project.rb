require 'strip_tags'

# Strips a project by stripping the specified #ifdef tags from all C++ files in the project
# You can also configure directory and file patterns that should be stripped.
class StripProject
	# ifdef tags that should be stripped
	attr_accessor :tags
	
	# if non-nil specifies tags that the stripped tags should be replaced with
	attr_accessor :replace_tags
	
	# Glob patterns for files and directories that should be skipped in the copy
	attr_accessor :prune
	
	# File extensions for which the ifdef stripping should be run
	# Default is %w(.h .cpp .inl .c .cc, .cxx)
	attr_accessor :strip_ext

	def initialize(tags = nil, replace_tags = nil, prune = nil)
		@tags = tags || []
		@replace_tags = replace_tags || @tags
		@prune = prune || []
		@strip_ext = %w(.h .cpp .inl .c .cc, .cxx)
	end
	
	def run(dir_from, dir_to)
		@strip_tags = StripTags.new(tags, replace_tags)
		Find.find(dir_from) do |from|
			rel = from.dup
			if rel == dir_from then rel = "" else rel["#{dir_from}/"] = "" end
			prune = @prune.any? {|f| File.fnmatch(f,rel)}

			if File.directory?(from)
				Find.prune if prune
				next
			end
			next if prune
			
			to = from.dup
			to[dir_from] = dir_to
			ext = File.extname(from)
			case ext
				when *@strip_ext then strip(from, to)
				else copy(from, to)
			end
		end
		@strip_tags = nil
	end
	
	private
	
	def strip(from, to)
		FileUtils.mkdir_p(File.dirname(to))
		text = @strip_tags.filter(IO.read(from), from)
		File.open(to, "w") {|f| f.write(text)}
	end
	
	def copy(from, to)
		FileUtils.mkdir_p(File.dirname(to))
		begin
			FileUtils.cp(from, to)
		rescue => e
			puts e.message
		end
	end
end