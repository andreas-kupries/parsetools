# -*- tcl -*-
# Copyright (c) 2009-2012 Andreas Kupries <andreas_kupries@sourceforge.net>

# Grammar expression handling.
# - (De)serialize expressions, various formats
# - Validate expressions.
# - Walk (visit) expressions.

# # ## ### ##### ######## ############# #####################
## Requirements

package require Tcl 8.5              ; # Required runtime.
package require lambda               ; # Readable apply.
package require try                  ; # try/finally for 8.5
package require pt::operator         ; # Operators in expressions.

# # ## ### ##### ######## ############# #####################
## API visibility

namespace eval ::pt::expr {
    namespace export {[a-z]*}
    namespace ensemble create

    namespace import ::pt::operator
}

namespace eval ::pt {
    namespace export expr
    namespace ensemble create
}

# # ## ### ##### ######## ############# #####################
## Public API I - Visit expressions.
##
## - Bottom up.             Generation of synthetic attributes.
## - Top-down (left-right). Management of an inherited context.
## - Down/up. Combination managing an inherit context and synthetic attributes.

namespace eval ::pt::expr::walk {
    namespace export up down
    namespace ensemble create
}

proc ::pt::expr::walk::up {cmdprefix expression} {
    if {![operator valid $expression msg]} {
	return -code error -errorcode {PT EXPR INVALID} $msg
    }

    set arguments [lassign $expression operator]

    set spec [dict get [operator definition $operator] spec]

    # Extend spec to match the arguments. This can only happen for
    # max-arity == +Inf, any other mismatch is rejected by the
    # validation above.
    set k [llength $spec]
    set n [llength $arguments]
    if {$k < $n} {
	lappend spec {*}[lrepeat [- $n $k] [lindex $spec end]]
    }

    # Process the arguments first (bottom-up!)
    foreach s $spec a $arguments {
	if {$s eq "-"} {
	    lappend eargs $a
	} else {
	    # Recurse into expression arguments.
	    lappend eargs [up $cmdprefix $a]
	}
    }

    # Now process the current node, providing both original and
    # processed arguments to the callback.

    # Note: The operator name is used as sub-method in the call. The
    # result of the call goes into the caller as part of the processed
    # information.

    return [{*}$cmdprefix $operator $expression $arguments $eargs]
}

proc ::pt::expr::walk::down {contextvar cmdprefix expression} {
    upvar 1 $contextvar context

    if {![operator valid $expression msg]} {
	return -code error -errorcode {PT EXPR INVALID} $msg
    }

    set arguments [lassign $expression operator]

    # Process the current node first, providing context and original
    # arguments to the callback. Note: The operator name is used as
    # sub-method in the call. The result of the call is ignored.

    {*}$cmdprefix $operator context $expression $arguments

    # The context however may have changed and is provided to the
    # child nodes, whose processing is now done.

    set spec [dict get [operator definition $operator] spec]

    # Extend spec to match the arguments. This can only happen for
    # max-arity == +Inf, any other mismatch is rejected by the
    # validation above.
    set k [llength $spec]
    set n [llength $arguments]
    if {$k < $n} {
	lappend spec {*}[lrepeat [- $n $k] [lindex $spec end]]
    }

    # Process the arguments last
    foreach s $spec a $arguments {
	if {$s eq "*"} {
	    # Recurse into expression arguments.
	    down context $cmdprefix $a
	}
    }
    return
}

proc ::pt::expr::walk::downup {contextvar cmdprefix expression} {
    upvar 1 $contextvar context

    if {![operator valid $expression msg]} {
	return -code error -errorcode {PT EXPR INVALID} $msg
    }

    set arguments [lassign $expression operator]

    # Process the current node first, providing context and original
    # arguments to the callback. Note: The operator name is used as
    # sub-method in the call. The result of the call is ignored.

    {*}$cmdprefix $operator down context $expression $arguments

    # The context however may have changed and is provided to the
    # child nodes, whose processing is now done.

    set spec [dict get [operator definition $operator] spec]

    # Extend spec to match the arguments. This can only happen for
    # max-arity == +Inf, any other mismatch is rejected by the
    # validation above.
    set k [llength $spec]
    set n [llength $arguments]
    if {$k < $n} {
	lappend spec {*}[lrepeat [- $n $k] [lindex $spec end]]
    }

    # Process the arguments...
    foreach s $spec a $arguments {
	if {$s eq "-"} {
	    lappend eargs $a
	} else {
	    # Recurse into expression arguments.
	    lappend eargs [downup context $cmdprefix $a]
	}
    }

    # And process the current node a second time as we come back from
    # the children.

    return [{*}$cmdprefix $operator up context $expression $arguments $eargs]
}

# # ## ### ##### ######## #############
## Public API II - validation, validation-as-canonical, printing

proc ::pt::expr::valid {expression msgvar} {
    # Validate the entire expression. The specified callback does
    # nothing, because the checks are done by the walker itself.

    try {
	walk up [lambda {op expression oargs eargs} {}] $expression
    } trap {PT EXPR INVALID} {e o} {
	upvar 1 $msgvar msg
	set msg $e
	return no
    }
    return yes
}

proc ::pt::expr::canonical {expression msgvar} {
    try {
	walk up [lambda@ [namespace current] {op expression oargs eargs} {
	    if {![operator canonical $expression msg]} {
		return -code error -errorcode {PT EXPR INVALID} $msg
	    }
	    return
	}] $expression
    } trap {PT EXPR INVALID} {e o} {
	upvar 1 $msgvar msg
	set msg $e
	return no
    }
    return yes
}

proc ::pt::expr::print {expression} {
    walk up [lambda@ [namespace current] {op expression oargs eargs} {
	set     out {}
	lappend out [operator print $expression]

	if {![operator leaf $op]} {
	    foreach a $eargs {
		foreach line $a {
		    lappend out "    $line"
		}
	    }
	}
	return $out
    }] $expression
}

proc ::pt::expr::makecanon {expression} {
    walk up [lambda@ [namespace current] {op expression oargs eargs} {
	operator makecanon [list $op {*}$eargs]
    }] $expression
}

proc ::pt::expr::equal {a b} {
    string equal [makecanon $a] [makecanon $b]
}

# # ## ### ##### ######## ############# #####################
## Ready

package provide pt::expr 1
return
