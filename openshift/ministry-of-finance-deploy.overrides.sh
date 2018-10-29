# ================================================================================================================
# Special deployment parameters needed for injecting a user supplied settings into the deployment configuration
# ----------------------------------------------------------------------------------------------------------------
# The results need to be encoded as OpenShift template parameters for use with oc process.
# ================================================================================================================

# ================================================================================================================
# Functions
# ----------------------------------------------------------------------------------------------------------------
printStatusMsg(){
  (
    _msg=${1}
    _yellow='\033[1;33m'
    _nc='\033[0m' # No Color
    printf "\n${_yellow}${_msg}\n${_nc}" >&2
  )
}

readParameter(){
  (
    _msg=${1}
    _paramName=${2}
    _defaultValue=${3}
    _encode=${4}

    _yellow='\033[1;33m'
    _nc='\033[0m' # No Color
    _message=$(echo -e "\n${_yellow}${_msg}\n${_nc}")

    read -r -p $"${_message}" ${_paramName}
    writeParameter "${_paramName}" "${_defaultValue}" "${_encode}"
  )
}

writeParameter(){
  (
    _paramName=${1}
    _defaultValue=${2}
    _encode=${3}

    if [ -z "${_encode}" ]; then
      echo "${_paramName}=${!_paramName:-${_defaultValue}}" >> ${_overrideParamFile}
    else
      # The key/value pair must be contained on a single line
      _encodedValue=$(echo -n "${!_paramName:-${_defaultValue}}"|base64 -w 0)
      echo "${_paramName}=${_encodedValue}" >> ${_overrideParamFile}
    fi
  )
}

generateKey(){
  (
    _length=${1:-48}
    # Format can be `-base64` or `-hex`
    _format=${2:--base64}

    echo $(openssl rand ${_format} ${_length})
  )
}

generateSeed(){
  (
    _prefix=${1}
    _seed=$(echo "${_prefix}$(generateKey 32)" | fold -w 32 | head -n 1 )
    _seed=$(echo -n "${_seed}")
    echo ${_seed}
  )
}

generateUsername() {
  # Generate a random username ...
  _userName=User_$( generateKey | LC_CTYPE=C tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1 )
  _userName=$(echo -n "${_userName}")
  echo ${_userName}
}

generatePassword() {
  # Generate a random password ...
  _password=$( generateKey | LC_CTYPE=C tr -dc 'a-zA-Z0-9_' | fold -w 20 | head -n 1 )
  _password=$(echo -n "${_password}")
  echo ${_password}
}

initialize(){
  # Define the name of the override param file.
  _scriptName=$(basename ${0%.*})
  export _overrideParamFile=${_scriptName}.param

  printStatusMsg "Initializing ${_scriptName} ..."

  # Remove any previous version of the file ...
  if [ -f ${_overrideParamFile} ]; then
    printStatusMsg "Removing previous copy of ${_overrideParamFile} ..."
    rm -f ${_overrideParamFile}
  fi
}
# ================================================================================================================

# ================================================================================================================
# Main Scipt Starts Here ...
# ----------------------------------------------------------------------------------------------------------------
initialize

# Ask the user to supply the sensitive parameters ...
readParameter "WALLET_ENCRYPTION_KEY - Please provide the wallet encryption key for the environment.  If left blank, a 48 character long base64 encoded value will be randomly generated using openssl:" WALLET_ENCRYPTION_KEY $(generateKey) "true"

_walletPrefix="MOFI"
_holderWalletPrefix="${_walletPrefix}H"
_verifierWalletPrefix="${_walletPrefix}V"
_issuerWalletPrefix="${_walletPrefix}I"

# The Ministry of Finance does not use a holder or verifier wallet at the moment so just generate seeds without asking ...
# readParameter "HOLDER_WALLET_SEED - Please provide the holder wallet seed for the environment.  If left blank, a seed will be randomly generated using openssl:" HOLDER_WALLET_SEED $(generateSeed ${_holderWalletPrefix}) "true"
# readParameter "VERIFIER_WALLET_SEED - Please provide the verifier wallet seed for the environment.  If left blank, a seed will be randomly generated using openssl:" VERIFIER_WALLET_SEED $(generateSeed ${_verifierWalletPrefix}) "true"
writeParameter "HOLDER_WALLET_SEED" $(generateSeed ${_holderWalletPrefix}) "true"
writeParameter "VERIFIER_WALLET_SEED" $(generateSeed ${_verifierWalletPrefix}) "true"

readParameter "ISSUER_WALLET_SEED - Please provide the issuer wallet seed for the environment.  If left blank, a seed will be randomly generated using openssl:" ISSUER_WALLET_SEED $(generateSeed ${_issuerWalletPrefix}) "true"

# The Ministry of Finance does not use a holder or verifier wallet at the moment so just write the DIDs without asking ...
# readParameter "HOLDER_WALLET_DID - Please provide the holder wallet did for the environment.  The default is an empty string:" HOLDER_WALLET_DID "" "true"
# readParameter "VERIFIER_WALLET_DID - Please provide the verifier did seed for the environment.  The default is an empty string:" VERIFIER_WALLET_DID "" "true"
writeParameter "HOLDER_WALLET_DID" "" "true"
writeParameter "VERIFIER_WALLET_DID" "" "true"

readParameter "ISSUER_WALLET_DID - Please provide the issuer wallet did for the environment.  The default is an empty string:" ISSUER_WALLET_DID "" "true"

SPECIALDEPLOYPARMS="--param-file=${_overrideParamFile}"
echo ${SPECIALDEPLOYPARMS}
# ================================================================================================================