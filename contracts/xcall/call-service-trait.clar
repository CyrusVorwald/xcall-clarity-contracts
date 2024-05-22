(define-trait call-service-trait
  (
    ;; Get the network address
    (get-network-address () (response (string-ascii 50) uint))

    ;; Get the network ID
    (get-network-id () (response (string-ascii 50) uint))

    ;; Get the fee for delivering a message to the specified network
    (get-fee ((string-ascii 50) bool (optional (list 50 (string-ascii 50)))) (response uint uint))

    ;; Send a call message to the contract on the destination chain
    (send-call-message ((string-ascii 150) (buff 1024) (optional (buff 1024)) (optional (list 50 (string-ascii 50))) (optional (list 50 (string-ascii 50)))) (response uint uint))

    ;; Send a call to the specified address with the given data
    (send-call ((string-ascii 150) (buff 1024)) (response uint uint))

    ;; Execute a rollback for the specified serial number
    (execute-rollback (uint) (response bool uint))

    ;; Execute a call for the specified request ID and calldata
    (execute-call (uint (buff 1024)) (response bool uint))

    ;; Handle an incoming BTP message from another blockchain
    (handle-message ((string-ascii 50) (buff 1024)) (response bool uint))

    ;; Handle an error in delivering a message
    (handle-error (uint) (response bool uint))
  )
)