(define-trait connection-trait
  (
    ;; Send the message to a specific network
    (send-message ((string-ascii 50) (string-ascii 50) int (buff 1024)) (response uint uint))
    ;; Get the fee to the target network
    (get-fee ((string-ascii 50) bool) (response uint uint))

    ;; Set the address of the admin
    (set-admin (principal) (response bool uint))

    ;; Get the address of the admin
    (get-admin () (response principal uint))
  )
)