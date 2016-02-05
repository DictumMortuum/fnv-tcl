package provide fnv 1.0

namespace eval fnv {

	namespace export fnv1a
	namespace export fnv1
	namespace export fnv_mask

	#
	# Magic numbers for 32-bit and 64-bit fnv1 and fnv1a.
	# Taken from http://www.isthe.com/chongo/tech/comp/fnv/index.html
	#

	# format 0x%x [expr [expr {[expr 1 << 24] + [expr 1 << 8]} + 0x93]]
	set FNV(prime,32)  0x01000193
	# format 0x%x [expr [expr {[expr 1 << 40] + [expr 1 << 8]} + 0xb3]]
	set FNV(prime,64)  0x100000001b3
	set FNV(offset,32) 0x811c9dc5
	set FNV(offset,64) 0xcbf29ce484222325
}

# The core FNV hash.

proc ::fnv::fnv1 {{input ""} {bits 64}} {

	if {[expr {$bits % 8}] != 0} {
		return -1
	}

	set result $fnv::FNV(offset,$bits)
	set prime  $fnv::FNV(prime,$bits)

	foreach c [split $input ""] {
		set result [format 0x%x [expr {$result * $prime}]]
		set result [format 0x%x [expr {$result ^ [scan $c %c]}]]

		if {$bits == 32} {
			set result "0x[string range $result end-7 end]"
		}
	}

	return $result
}

# A minor FNV hash variation.
# This algorithm has a slightly better dispersion for tiny (<4 octets) chunks of memory.
# It's recommended in the documentation to use the alternative algorithm instead of the FNV-1 hash where possible.

proc ::fnv::fnv1a {{input ""} {bits 64}} {

	if {[expr {$bits % 8}] != 0} {
		return -1
	}

	set result $fnv::FNV(offset,$bits)
	set prime  $fnv::FNV(prime,$bits)

	foreach c [split $input ""] {
		set result [format 0x%x [expr {$result ^ [scan $c %c]}]]
		set result [format 0x%x [expr {$result * $prime}]]

		if {$bits == 32} {
			set result "0x[string range $result end-7 end]"
		}
	}

	return $result
}

#
# Taken from http://www.isthe.com/chongo/tech/comp/fnv/index.html under "xor-folding".
# 
# If you need a x-bit hash where x is not a power of 2, then we recommend that you compute the FNV hash
# that is just larger than x-bits and xor-fold the result down to x-bits. By xor-folding we mean shift
# the excess high order bits down and xor them with the lower x-bits.
#

proc ::fnv::fnv_mask {{input ""} {bits 64} {func "fnv1a"}} {

	if {$bits <= 0 || $bits > 64} {
		return -1
	} elseif {$bits > 0 && $bits < 16} {
		set init 32
		set tiny 1
	} elseif {$bits >= 16 && $bits < 32} {
		set init 32
		set tiny 0
	} elseif {$bits > 32 && $bits < 64} {
		set init 64
		set tiny 0
	} elseif {$bits == 32 || $bits == 64} {
		return [$func $input $bits]
	}

	set mask [format 0x%x [expr {[expr {1 << $bits}] - 1}]]
	set hash [$func $input $init]

	if {$tiny == 0} {
		set mask [format 0x%x [expr {$hash &  $mask}]]
		set hash [format 0x%x [expr {$hash >> $bits}]]
		return   [format 0x%x [expr {$hash ^  $mask}]]
	} else {

		# For tiny x < 16 values, we recommend using a 32-bit FNV hash as follows:

		set temp $hash
		set hash [format 0x%x [expr {$hash >> $bits}]]
		set hash [format 0x%x [expr {$hash ^  $temp}]]
		return   [format 0x%x [expr {$hash &  $mask}]]
	}
}
