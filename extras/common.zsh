die () { >&2 echo "$1" ; exit "${2:-1}" }

ajoin () { local IFS=$1 ; shift ; echo -n "$*" }
asplit () { IFS=$2 read -Ar "$1" <<<"$3" }

math-max () { (( $2 > $1 )) && (( $2 )) || (( $1 )) ; : }
functions -M max 2 2 math-max

math-min () { (( $2 < $1 )) && (( $2 )) || (( $1 )) ; : }
functions -M min 2 2 math-min
