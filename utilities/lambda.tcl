# -*- tcl -*-
#
# Copyright (c) 2012 by Andreas Kupries <andreas_kupries@users.sourceforge.net>
# Wrapper to make [apply] more readable.

# XXX TODO: Documentation. Tests.

# ### ### ### ######### ######### #########
## Requisites

package require Tcl 8.5

# ### ### ### ######### ######### #########

proc lambda {arguments body args} {
    return [list ::apply [list $arguments $body] {*}$args]
}

proc lambda@ {ns arguments body args} {
    return [list ::apply [list $arguments $body $ns] {*}$args]
}

# ### ### ### ######### ######### #########
## Ready

package provide lambda 1
return
