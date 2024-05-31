;; title: call-service
;; version:
;; summary:
;; description:

;; traits
(impl-trait .call-service-trait.call-service-trait)
(use-trait call-service-receiver-trait .call-service-receiver-trait.call-service-receiver-trait)
(use-trait connection-trait .connection-trait.connection-trait)
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
(define-constant ERR_INVALID_MESSAGE_HASH (err u106))
(define-constant ERR_UNSUPPORTED_FUNCTION (err u107))
(define-constant ERR_UNKNOWN_MESSAGE_TYPE (err u108))
(define-constant ERR_TRANSFER_FAILED (err u109))
(define-constant ERR_UNSUPPORTED_CONTRACT (err u110))

(define-constant MAX_SEQUENCE (- (pow u2 u64) u1))
(define-constant PROTOCOL_FEE u1000)

(define-constant CALL_MESSAGE_TYPE u1)
(define-constant CALL_MESSAGE_WITH_ROLLBACK_TYPE u2)
(define-constant PERSISTENT_MESSAGE_TYPE u3)
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
(define-map proxyReqs uint { from: (string-ascii 150), to: (string-ascii 150), sn: uint, type: uint, data: (buff 32), protocols: (list 10 (string-ascii 50)) })
;;

;; public functions
(define-read-only (get-chain-identifier (network-address (string-ascii 150)))
  ;; TODO: Extract the chain ID from the network address
  (ok "chain-identifier")
)

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
        (print (merge { event: "send-message" } { from: tx-sender, to: to, sequence: sequence, data: data }))
        (ok sequence)
      )
    )
  )
)

(define-public (handle-message (from (string-ascii 150)) (sequence uint) (data (buff 1024)))
  (let ((chain-identifier (unwrap-panic (get-chain-identifier from))))
    (let ((contract-address (unwrap-panic (contract-call? .util address-string-to-principal (unwrap-panic (as-max-len? from u128))))))
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
                (handle-call-message from (unwrap-panic (element-at? (contract-call? .rlp-decode rlp-decode-buff decoded-data u1) u0)))
                (if (is-eq message-type CALL_MESSAGE_WITH_ROLLBACK_TYPE)
                    (handle-call-message-with-rollback from (unwrap-panic (element-at? (contract-call? .rlp-decode rlp-decode-buff decoded-data u1) u0)) (unwrap-panic (element-at? (contract-call? .rlp-decode rlp-decode-buff decoded-data u2) u0)))
                    (if (is-eq message-type PERSISTENT_MESSAGE_TYPE)
                        (handle-persistent-message from (unwrap-panic (element-at? (contract-call? .rlp-decode rlp-decode-buff decoded-data u1) u0)))
                        (begin
                          (print (merge { event: "unknown-message-type" } { message-type: message-type }))
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

;; Execute a cross-chain message
(define-public (execute-call (id uint) (data (buff 1024)))
  (ok true)
)

(define-public (execute-rollback (id uint))
  (ok true)
)

;; (define-public (execute-call (id uint) (data (buff 1024)))
;;   (match (map-get? proxyReqs id)
;;     req (begin
;;       (map-delete proxyReqs id)
;;       (asserts! (is-eq (hash (unwrap-panic req)) (hash data)) ERR_INVALID_MESSAGE_HASH)
;;       (execute-message id req)
;;     )
;;     (err ERR_MESSAGE_NOT_FOUND)
;;   )
;; )

;; (define-private (execute-message (id uint) (req { from: (string-ascii 150), to: (string-ascii 150), sn: uint, type: uint, data: (buff 1024), protocols: (list 10 (string-ascii 50)) }))
;;   (let ((msg-type (get type req)))
;;     (if (is-eq msg-type CALL_MESSAGE_TYPE)
;;       (try-execute id (get from req) (get data req) (get protocols req))
;;       (if (is-eq msg-type CALL_MESSAGE_WITH_ROLLBACK_TYPE)
;;         (begin
;;           (try-execute id (get from req) (get data req) (get protocols req))
;;           (let ((rollback-data (unwrap-panic (map-get? rollbacks (get sn req)))))
;;             (map-set rollbacks (get sn req) (merge rollback-data { enabled: true }))
;;           )
;;         )
;;         (if (is-eq msg-type PERSISTENT_MESSAGE_TYPE)
;;           (try-execute id (get from req) (get data req) (get protocols req))
;;           (begin
;;             (print { event: "unsupported-message-type", message-type: msg-type })
;;             (err ERR_UNKNOWN_MESSAGE_TYPE)
;;           )
;;         )
;;       )
;;     )
;;   )
;; )

;; (define-private (try-execute (id uint) (from (string-ascii 150)) (data (buff 1024)) (protocols (list 10 (string-ascii 50))) (target-contract <call-service-receiver-trait>))
;;   (let ((result (contract-call? target-contract handle-call-message from data protocols)))
;;     (match result
;;       success (begin
;;         (print { event: "call-executed", id: id, code: u1, msg: "success" })
;;         (ok true)
;;       )
;;       error (begin
;;         (print { event: "call-executed", id: id, code: u0, msg: "error" })
;;         (ok false)
;;       )
;;     )
;;   )
;; )

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

(define-public (get-fee (chain-identifier (string-ascii 50)) (rollback bool) (sources (optional (list 50 (string-ascii 50)))))
  (let ((protocol-fee-local (var-get protocol-fee)))
      (match (map-get? default-connections { chain-identifier: chain-identifier })
        entry (let ((connection (get connection entry)))
                (unwrap-panic
                  (get-connection-fee connection chain-identifier rollback)))
        (err ERR_NO_DEFAULT_CONNECTION))))

(define-private (get-connection-fee (connection <connection-trait>) (chain-identifier (string-ascii 50)) (rollback bool))
  (contract-call? connection get-fee chain-identifier rollback))

;; (define-private (get-total-fee (connection (string-ascii 50)) (total uint))
;;   (let ((fee (unwrap-panic (contract-call? (as-contract tx-sender) get-fee connection))))
;;     (+ total fee)))

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

;; (define-read-only (get-chain-identifier (network-address (string-ascii 150)))
;;   ;; TODO: Extract the chain ID from the network address
;;   (ok "chain-identifier")
;; )
;;

;; private functions
;; (define-private (get-current-sequence (chain-identifier (string-ascii 50)) (contract-address principal))
;;   (match (map-get? message-sequences { chain-identifier: chain-identifier, contract-address: contract-address })
;;     entry (ok (get current-sequence entry))
;;     (ok u0)
;;   )
;; )

;; (define-private (increment-sequence (chain-identifier (string-ascii 50)) (contract-address principal))
;;   (let ((current-sequence (unwrap-panic (get-current-sequence chain-identifier contract-address))))
;;     (asserts! (< current-sequence MAX_SEQUENCE) ERR_INVALID_SEQUENCE)
;;     (map-set message-sequences { chain-identifier: chain-identifier, contract-address: contract-address } { current-sequence: (+ current-sequence u1) })
;;     (ok true)
;;   )
;; )

(define-private (hash (data (buff 1024)))
  ;; used for tests. simnet can only call contracts, not builtin hash160
  (ok (hash160 data))
)

(define-private (handle-call-message (from (string-ascii 150)) (data (buff 1024)))
  (let ((decoded-data (contract-call? .rlp-decode rlp-to-list data)))
    (let ((target-contract (contract-call? .rlp-decode rlp-decode-string decoded-data u0)))
      (let ((function-name (contract-call? .rlp-decode rlp-decode-string decoded-data u1)))
        (let ((args (contract-call? .rlp-decode rlp-decode-list decoded-data u2)))
          (if (is-eq target-contract "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.my-contract")
              (if (is-eq function-name "function1")
                  (handle-function1 from args)
                  (if (is-eq function-name "function2")
                      (handle-function2 from args)
                      (begin
                        (print (merge { event: "unsupported-function" } { target-contract: target-contract, function-name: function-name }))
                        ERR_UNSUPPORTED_FUNCTION
                      )
                  )
              )
              (begin
                (print (merge { event: "unsupported-contract" } { target-contract: target-contract }))
                ERR_UNSUPPORTED_CONTRACT
              )
          )
        )
      )
    )
  )
)

(define-private (handle-call-message-with-rollback (from (string-ascii 150)) (data (buff 1024)) (rollback-data (buff 1024)))
  (let ((decoded-data (contract-call? .rlp-decode rlp-to-list data)))
    (let ((target-contract (contract-call? .rlp-decode rlp-decode-string decoded-data u0)))
      (let ((function-name (contract-call? .rlp-decode rlp-decode-string decoded-data u1)))
        (let ((args (contract-call? .rlp-decode rlp-decode-list decoded-data u2)))
          (if (is-eq target-contract "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.my-contract")
              (if (is-eq function-name "function1")
                  (handle-function1-with-rollback from args rollback-data)
                  (if (is-eq function-name "function2")
                      (handle-function2-with-rollback from args rollback-data)
                      (begin
                        (print (merge { event: "unsupported-function" } { target-contract: target-contract, function-name: function-name }))
                        ERR_UNSUPPORTED_FUNCTION
                      )
                  )
              )
              (begin
                (print (merge { event: "unsupported-contract" } { target-contract: target-contract }))
                ERR_UNSUPPORTED_CONTRACT
              )
          )
        )
      )
    )
  )
)

(define-private (handle-persistent-message (from (string-ascii 150)) (data (buff 1024)))
  (let ((decoded-data (contract-call? .rlp-decode rlp-to-list data)))
    (let ((target-contract (contract-call? .rlp-decode rlp-decode-string decoded-data u0)))
      (let ((function-name (contract-call? .rlp-decode rlp-decode-string decoded-data u1)))
        (let ((args (contract-call? .rlp-decode rlp-decode-list decoded-data u2)))
          (if (is-eq target-contract "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.my-contract")
              (if (is-eq function-name "function3")
                  (handle-function3 from args)
                  (if (is-eq function-name "function4")
                      (handle-function4 from args)
                      (begin
                        (print (merge { event: "unsupported-function" } { target-contract: target-contract, function-name: function-name }))
                        ERR_UNSUPPORTED_FUNCTION
                      )
                  )
              )
              (begin
                (print (merge { event: "unsupported-contract" } { target-contract: target-contract }))
                ERR_UNSUPPORTED_CONTRACT
              )
          )
        )
      )
    )
  )
)
;;

;;;;;;;;; dapp functions
(define-private (handle-function1 (from (string-ascii 150)) (args (list 500 (buff 1024))))
  ;; Implement the logic for handling function1
  ;; Extract the necessary arguments from 'args' using RLP decoding functions
  ;; Perform the desired operations
  ;; Return (ok true) on success or (err ERR_FUNCTION1_FAILED) on failure
  (ok true)
)

(define-private (handle-function2 (from (string-ascii 150)) (args (list 500 (buff 1024))))
  ;; Implement the logic for handling function2
  ;; Extract the necessary arguments from 'args' using RLP decoding functions
  ;; Perform the desired operations
  ;; Return (ok true) on success or (err ERR_FUNCTION2_FAILED) on failure
  (ok true)
)

(define-private (handle-function3 (from (string-ascii 150)) (args (list 500 (buff 1024))))
  ;; Implement the logic for handling function3
  ;; Extract the necessary arguments from 'args' using RLP decoding functions
  ;; Perform the desired operations
  ;; Return (ok true) on success or (err ERR_FUNCTION3_FAILED) on failure
  (ok true)
)

(define-private (handle-function4 (from (string-ascii 150)) (args (list 500 (buff 1024))))
  ;; Implement the logic for handling function4
  ;; Extract the necessary arguments from 'args' using RLP decoding functions
  ;; Perform the desired operations
  ;; Return (ok true) on success or (err ERR_FUNCTION4_FAILED) on failure
  (ok true)
)

(define-private (handle-function1-with-rollback (from (string-ascii 150)) (args (list 500 (buff 1024))) (rollback-data (buff 1024)))
  ;; Implement the logic for handling function1 with rollback
  ;; Extract the necessary arguments from 'args' using RLP decoding functions
  ;; Perform the desired operations and handle rollbacks if needed
  ;; Return (ok true) on success or (err ERR_FUNCTION1_FAILED) on failure
  (ok true)
)

(define-private (handle-function2-with-rollback (from (string-ascii 150)) (args (list 500 (buff 1024))) (rollback-data (buff 1024)))
  ;; Implement the logic for handling function2 with rollback
  ;; Extract the necessary arguments from 'args' using RLP decoding functions
  ;; Perform the desired operations and handle rollbacks if needed
  ;; Return (ok true) on success or (err ERR_FUNCTION2_FAILED) on failure
  (ok true)
)
