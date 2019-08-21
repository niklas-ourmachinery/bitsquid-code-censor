require 'strip_project'

# Sample script that uses the functionality to strip out platform specific code and files.

# Default stripping of PS3 code
def add_ps3_stripping(project)
	project.tags += %w(_PS3 CAN_COMPILE_PS3 SPU)
	project.replace_tags += %w(STRIPPED_PS3 STRIPPED_CAN_COMPILE_PS3 STRIPPED_SPU)
	project.prune += %w(application_ps3 edgepost_mlaa_task gcm_render_device libgtfconv psn)
	project.prune += %w(resources/ps3_dsp)
	project.prune += %w(documentation/*/*.ps3.txt)
end

# Default stripping of X360 code
def add_x360_stripping(project)
	project.tags += %w(_XBOX CAN_COMPILE_XBOX)
	project.replace_tags += %w(STRIPPED_XBOX STRIPPED_CAN_COMPILE_XBOX)
	project.prune += %w(application_x360 x360_render_device)
end

if __FILE__ == $0
	$:.unshift File.join(File.dirname(__FILE__), '..')
	
	project = StripProject.new()
	project.prune += %w(.hg)
	add_ps3_stripping(project)
	add_x360_stripping(project)
	project.run(ARGV[0], ARGV[1])
end