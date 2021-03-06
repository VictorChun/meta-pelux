function os.capture(cmd)
	local f = assert(io.popen(cmd, 'r'))
	local s = assert(f:read('*a'))
	f:close()
	return s
end

function file_exists(name)
	local f=io.open(name,"r")
	if f~=nil then io.close(f) return true else return false end
end

function cmdexec(cmd)
	local ret, s, status = os.execute(cmd)
	if (status ~= 0) then
		return false, cmd .. " return with error " .. status
	end

	return true,""
end

function preinst()
	local out
	local s1
	local ret

	local log = os.tmpname()

	local eMMC = "/dev/sda"
	ret = file_exists("/dev/sda")

	if (ret == false) then
		return false, "Cannot find eMMC"
	end

	ret, out = cmdexec("/usr/sbin/sfdisk -d " .. eMMC .. "> /tmp/dumppartitions")
	if (false == ret) then
		return ret, out
	end

	-- check if there are two identical partitions
	-- and create the second one if no available
	f = io.input("/tmp/dumppartitions")
	fo = io.output("/tmp/partitions")
	t = f:read()
	found = false
	while (t ~= nil) do
		j=0
		j=string.find(t, "/dev/sda3")
		ret, out = fo:write(t .. "\n")
		if (ret == nil) then
			fo:close()
			f:close()
			return false, out
		end
		if (j == 1) then
			found=true
			break
		end
		j=string.find(t, "/dev/sda2")
		if (j == 1) then
			start, size = string.match(t, "%a+%s*=%s*(%d+), size=%s*(%d+)")
		end
		t = f:read()
	end

	if (found) then
		f:close()
		fo:close()
		return true, out
	end

	start=start+size
	partitions = eMMC .. "3 : start=    " .. string.format("%d", start) .. ", size=  " .. size .. ", type=83\n"

	ret, out = fo:write(partitions)
	fo:close()
	f:close()

	if (ret == nil) then
		return false, out
	end

	out = os.capture("/usr/sbin/sfdisk --force " .. eMMC .. " < /tmp/partitions")

	-- use partprobe to inform the kernel of the new partitions

	ret, out = cmdexec("/usr/sbin/partprobe " .. eMMC)
	if (false == ret) then
		return ret, out
	end

	return true, out
end

function postinst()
	local out = "Post installed script called"

	ret, out = cmdexec("mkdir -p /tmp/mountedsda3")
	if (false == ret) then
		return ret, out
	end

	ret, out = cmdexec("mount /dev/sda3 /tmp/mountedsda3")
	if (false == ret) then
		return ret, out
	end

	ret, out = cmdexec("sed -i -e 's/alt/main/' /tmp/mountedsda3/lib/systemd/system/swupdate.service")
	if (false == ret) then
		return ret, out
	end

	ret, out = cmdexec("sed -i -e 's/-c [0-3]/-c 2/' /tmp/mountedsda3/lib/systemd/system/swupdate.service")
	if (false == ret) then
		return ret, out
	end

	ret, out = cmdexec("umount /tmp/mountedsda3")
	if (false == ret) then
		return ret, out
	end

	ret, out = cmdexec("rm -rf /tmp/mountedsda3")
	if (false == ret) then
		return ret, out
	end

	return true, out
end
