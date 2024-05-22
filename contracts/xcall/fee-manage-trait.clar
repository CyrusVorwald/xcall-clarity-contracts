(define-trait fee-manage-trait
  (
    ;; Set the address of the FeeHandler
    (set-protocol-fee-handler (principal) (response bool uint))
    ;; Get the current protocol fee handler address
    (get-protocol-fee-handler () (response principal uint))

    ;; Set the protocol fee amount
    (set-protocol-fee (uint) (response bool uint))

    ;; Get the current protocol fee amount
    (get-protocol-fee () (response uint uint))
  )
)