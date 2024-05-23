;; title: call-service
;; version:
;; summary:
;; description:

;; traits
;;

;; token definitions
;;

;; constants
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVALID_MESSAGE (err u101))
(define-constant ERR_INVALID_SEQUENCE (err u102))
(define-constant ERR_INSUFFICIENT_FEE (err u103))
(define-constant ERR_NO_DEFAULT_CONNECTION (err u104))
(define-constant ERR_MESSAGE_NOT_FOUND (err u105))
(define-constant MAX_SEQUENCE (- (pow u2 u64) u1))
(define-constant PROTOCOL_FEE u1000)
;;

;; data vars
(define-data-var admin principal tx-sender)
(define-data-var protocol-fee uint u1000)
(define-data-var fee-handler principal tx-sender)
;;

;; data maps
(define-map message-sequences { chain-identifier: (string-ascii 50), contract-address: principal } { current-sequence: uint })
(define-map message-hashes { chain-identifier: (string-ascii 50), sequence: uint } { hash: (buff 32) })
(define-map rollbacks { chain-identifier: (string-ascii 50), sequence: uint } { data: (buff 1024), rollback: (buff 1024) })
(define-map default-connections { chain-identifier: (string-ascii 50) } { connection: principal })
;;

;; public functions
(define-public (send-message (to (string-ascii 150)) (data (buff 1024)) (rollback (optional (buff 1024))) (fee uint))
  (let ((chain-identifier (unwrap-panic (get-chain-identifier to))))
    (asserts! (>= fee (var-get protocol-fee)) ERR_INSUFFICIENT_FEE)
    (let ((current-sequence (unwrap-panic (get-current-sequence chain-identifier (as-contract tx-sender)))))
      (let ((sequence (+ current-sequence u1)))
        (unwrap-panic (increment-sequence chain-identifier (as-contract tx-sender)))
        (map-set message-hashes { chain-identifier: chain-identifier, sequence: sequence } { hash: (hash160 data) })
        (if (is-some rollback)
            (map-set rollbacks { chain-identifier: chain-identifier, sequence: sequence } { data: data, rollback: (unwrap-panic rollback) })
            true)
        (print { from: tx-sender, to: to, sequence: sequence, data: data })
        (ok sequence)
      )
    )
  )
)

(define-public (handle-message (from (string-ascii 150)) (sequence uint) (data (buff 1024)))
  (let ((chain-identifier (unwrap-panic (get-chain-identifier from))))
    (let ((contract-address (unwrap-panic (contract-call? .util address-string-to-principal (unwrap-panic (as-max-len? from 128))))))
      (let ((current-sequence (unwrap-panic (get-current-sequence chain-identifier contract-address))))
        (asserts! (is-eq sequence (+ current-sequence u1)) ERR_INVALID_SEQUENCE)
        (unwrap-panic (increment-sequence chain-identifier contract-address))

        (let ((expected-hash (unwrap-panic (get-message-hash chain-identifier sequence))))
          (let ((actual-hash (hash160 data)))
            (asserts! (is-eq expected-hash actual-hash) ERR_INVALID_MESSAGE_HASH)
          )
        )

        (let ((decoded-data (contract-call? .rlp-decode rlp-to-list data)))
          (let ((message-type (contract-call? .rlp-decode rlp-decode-uint decoded-data u0)))
            (if (is-eq message-type CALL_MESSAGE_TYPE)
                (handle-call-message from (contract-call? .rlp-decode rlp-decode-buff decoded-data u1))
                (if (is-eq message-type CALL_MESSAGE_WITH_ROLLBACK_TYPE)
                    (handle-call-message-with-rollback from (contract-call? .rlp-decode rlp-decode-buff decoded-data u1) (rlp-decode-buff decoded-data u2))
                    (if (is-eq message-type PERSISTENT_MESSAGE_TYPE)
                        (handle-persistent-message from (contract-call? .rlp-decode rlp-decode-buff decoded-data u1))
                        (begin
                          (print "unknown-message-type" { message-type: message-type })
                          ERR_UNKNOWN_MESSAGE_TYPE
                        )
                    )
                )
            )
          )
        )
      )
    )
  )
)

;; (define-private (handle-call-message (from (string-ascii 150)) (data (buff 1024)))
;;   (let ((decoded-data (contract-call? .rlp-decode rlp-to-list data)))
;;     (let ((target-contract (unwrap-panic (contract-call? .util address-string-to-principal (unwrap-panic (as-max-len? (contract-call? .rlp-decode rlp-decode-string decoded-data u0) u128))))))
;;       (let ((function-name (contract-call? .rlp-decode rlp-decode-string decoded-data u1)))
;;         (let ((args (contract-call? .rlp-decode rlp-decode-list decoded-data u2)))
;;           (if (is-eq function-name "execute")
;;               (let ((amount (contract-call? .rlp-decode rlp-decode-uint args u0)))
;;                 (let ((token (unwrap-panic (contract-call? .util address-string-to-principal (unwrap-panic (as-max-len? (contract-call? .rlp-decode rlp-decode-string args u1) u128))))))
;;                   (let ((sender (unwrap-panic (contract-call? .util address-string-to-principal (unwrap-panic (as-max-len? from u128))))))
;;                     (if (is-eq contract-caller tx-sender)
;;                         (begin
;;                           (try! (as-contract (contract-call? token transfer amount tx-sender sender none)))
;;                           (print "execute-success" { from: from, target-contract: target-contract })
;;                           (ok true)
;;                         )
;;                         (begin
;;                           (print "unauthorized-caller" { caller: contract-caller })
;;                           ERR_UNAUTHORIZED
;;                         )
;;                     )
;;                   )
;;                 )
;;               )
;;               (begin
;;                 (print "unsupported-function" { function-name: function-name })
;;                 ERR_UNSUPPORTED_FUNCTION
;;               )
;;           )
;;         )
;;       )
;;     )
;;   )
;; )

;; (define-private (handle-call-message (from (string-ascii 150)) (data (buff 1024)))
;;   (let ((decoded-data (contract-call? .rlp-decode rlp-to-list data)))
;;     (let ((target-contract (contract-call? .rlp-decode rlp-decode-string decoded-data u0)))
;;       (let ((function-name (contract-call? .rlp-decode rlp-decode-string decoded-data u1)))
;;         (let ((args (contract-call? .rlp-decode rlp-decode-list decoded-data u2)))
;;           (if (and (is-eq target-contract "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.contract-goes-here") (is-eq function-name "transfer"))
;;               (let ((amount (contract-call? .rlp-decode rlp-decode-uint args u0)))
;;                 (let ((recipient (unwrap-panic (contract-call? .util address-string-to-principal (unwrap-panic (as-max-len? (contract-call? .rlp-decode rlp-decode-string args u1) 128))))))
;;                   (let ((sender (unwrap-panic (contract-call? .util address-string-to-principal from))))
;;                     (if (is-eq contract-caller tx-sender)
;;                         (begin
;;                           (try! (as-contract (contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.contract-goes-here transfer amount tx-sender recipient none)))
;;                           (print "transfer-success" { from: from, recipient: recipient, amount: amount })
;;                           (ok true)
;;                         )
;;                         (begin
;;                           (print "unauthorized-caller" { caller: contract-caller })
;;                           ERR_UNAUTHORIZED
;;                         )
;;                     )
;;                   )
;;                 )
;;               )
;;               (begin
;;                 (print "unsupported-function" { target-contract: target-contract, function-name: function-name })
;;                 ERR_UNSUPPORTED_FUNCTION
;;               )
;;           )
;;         )
;;       )
;;     )
;;   )
;; )

;; Execute a cross-chain message
(define-public (execute-message (chain-identifier (string-ascii 50)) (sequence uint) (data (buff 1024)))
  ;; TODO: Implement logic to execute the message on the target contract
  ;; TODO: Update message status and emit relevant events
  (ok true)
)

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (ok true)
  )
)

(define-public (set-protocol-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set protocol-fee new-fee)
    (ok true)
  )
)

(define-public (set-fee-handler (new-handler principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set fee-handler new-handler)
    (ok true)
  )
)

(define-public (set-default-connection (chain-identifier (string-ascii 50)) (connection principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (map-set default-connections { chain-identifier: chain-identifier } { connection: connection })
    (ok true)
  )
)
;;

;; read only functions
(define-read-only (get-admin)
  (ok (var-get admin))
)

(define-read-only (get-protocol-fee)
  (ok (var-get protocol-fee))
)

(define-read-only (get-fee-handler)
  (ok (var-get fee-handler))
)

(define-read-only (get-default-connection (chain-identifier (string-ascii 50)))
  (match (map-get? default-connections { chain-identifier: chain-identifier })
    entry (ok (get connection entry))
    (err ERR_NO_DEFAULT_CONNECTION)
  )
)

(define-read-only (get-message-hash (chain-identifier (string-ascii 50)) (sequence uint))
  (match (map-get? message-hashes { chain-identifier: chain-identifier, sequence: sequence })
    entry (ok (get hash entry))
    (err ERR_MESSAGE_NOT_FOUND)
  )
)

(define-read-only (get-chain-identifier (network-address (string-ascii 150)))
  ;; TODO: Extract the chain ID from the network address
  (ok "chain-identifier")
)
;;

;; private functions
(define-private (get-current-sequence (chain-identifier (string-ascii 50)) (contract-address principal))
  (match (map-get? message-sequences { chain-identifier: chain-identifier, contract-address: contract-address })
    entry (ok (get current-sequence entry))
    (ok u0)
  )
)

(define-private (increment-sequence (chain-identifier (string-ascii 50)) (contract-address principal))
  (let ((current-sequence (unwrap-panic (get-current-sequence chain-identifier contract-address))))
    (asserts! (< current-sequence MAX_SEQUENCE) ERR_INVALID_SEQUENCE)
    (map-set message-sequences { chain-identifier: chain-identifier, contract-address: contract-address } { current-sequence: (+ current-sequence u1) })
    (ok true)
  )
)

(define-private (hash (data (buff 1024)))
  ;; used for tests. simnet can only call contracts, not builtin hash160
  (ok (hash160 data))
)
;;