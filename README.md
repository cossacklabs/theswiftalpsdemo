# the Swift Alps demo

Code contains 2 examples:

- example of storage encryption
- example of transfer encryption


Please, see `AppDelegate` for entry point (comment/uncomment example you want to run).

## Storage encryption example 

[Secure Cell](https://github.com/cossacklabs/themis/wiki/Secure-Cell-cryptosystem) is container for symmetric encryption. Secure Cell provides:

- integrity protection (calculates ~hmac to ensure that message was not changed)
- context-dependent (both key and context are important)
- tampering protection


### Running example:


- Run CellDemo<br/>
  `CellDemo().runDemo()`
  
- Encrypt-decrypt several messages
- Can you decrypt messages using other context?

### What is wrong with this sample?
- Keys are plaintext.

Using any good storage encryption library makes your work useless if you store keys in plain text.


## Transfer encryption example 

[Secure Session](https://github.com/cossacklabs/themis/wiki/Secure-Session-cryptosystem) helps to establish session between two peers, within which data can be securely exchanged with higher security guarantees.

Create iOS app and server system to exchange the messages

1. secure end-to-end communication 
2. perfect forward secrecy
3. strong mutual peer authentication


### Running example 

1. Open [server dashboard](http://alps.cossacklabs.com/), copy serverId, url and public key.
2. In source code: update serverId, server url and server public key.
3. Run sample and send a message to the server
4. See it on the dashboard

### What is wrong with this sample?
- Keys are plaintext.
- ATS is disabled at all

Using any good transfer encryption library makes your work useless if you store keys in plain text and disable ATS.


## Links

- Swift docs for [Themis library](https://github.com/cossacklabs/themis/wiki/Swift-Howto).
- [SwiftAlps event](http://theswiftalps.com/)
- Links to [workshop slides](https://speakerdeck.com/vixentael/the-swift-alps-security-workshop)
