

let web3 = null

module.exports = {
	parseB32StringToUintArray: ( b32, num = 32 ) => {
 		let out = []
 		let offs = b32.substr(0,2) == '0x' ? 2 : 0 // work with or without '0x'
  	for (let i=0; i<num; i++) 
  		out[i] = parseInt( b32.substr(offs+i*4,4), 16 )  // ignore '0x' 
  	return out
	},

	hexToBytes : ( hex, num = 32 ) => {
    let bytes = []
    let n = num * 2
    let offs = hex.substr(0,2) == '0x' ? 2 : 0 // work with or without '0x'
    for ( c = 0; c < n; c += 2 )
      bytes.push(parseInt(hex.substr(c+offs, 2), 16))
    return bytes
  },

  hexToBytesSigned : ( hex, num = 32 ) => (
    module.exports.hexToBytes( hex, num ).map( byte => byte & 0x80 ? (byte & 0x7f) - 0x80 : byte )
  ),

	// Convert a byte array to a hex string
	bytesToHex: bytes => {
    for (let hex = [], i = 0; i < bytes.length; i++) {
      hex.push((bytes[i] >>> 4).toString(16));
      hex.push((bytes[i] & 0xF).toString(16));
    }
    return hex.join("");
	},

	toHexString: ( byteArray, prefix = true )  => {
  	return (prefix ? '0x' : '' ) + Array.from( byteArray, byte => {
    	return ('0' + (byte & 0xFF).toString(16)).slice(-2)
  	}).join('')
	},

  getWeb3: () => web3 || window.web3,
  setWeb3: w3 => web3 = w3, // used on server side



  /**
    * Run promises from array of functions that can return promises
    * in chained manner
    *
    * @param {array} pfn_arr - promise (function) array
    * @return {Object} promise object
  */
  runPromisesInSequence: ( pfn_arr, input ) =>  
    pfn_arr.reduce(
      ( promiseChain, currentFunction ) => promiseChain.then(currentFunction),
      Promise.resolve( input )
    )
}



