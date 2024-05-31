;; title: dapp-sample
;; version: 1.0.0
;; summary: A sample dapp for xCall in Clarity

(impl-trait .call-service-receiver-trait.call-service-receiver-trait)

;; constants
(define-constant ERR_ONLY_CALL_SERVICE (err u100))
(define-constant ERR_ROLLBACK_MISMATCH (err u101))
(define-constant CALL_SERVICE_NETWORK_ADDRESS "stacks-address")

;; data vars
(define-data-var call-svc principal tx-sender)
(define-data-var call-svc-net-addr (string-ascii 150) CALL_SERVICE_NETWORK_ADDRESS)
(define-data-var last-id uint u0)
(define-data-var tx-fee uint u1000)


;; data maps
(define-map rollbacks uint {
  id: uint,
  rollback: (buff 1024),
  ssn: uint
})

;; public functions
(define-public (send-message (to (string-ascii 150)) (data (buff 1024)) (rollback (buff 1024)))
  (let ((rollback-len (len rollback)))
    (if (> rollback-len u0)
      (let ((id (+ (var-get last-id) u1)))
        (var-set last-id id)
        (let ((sn (as-contract (contract-call? .call-service send-message to data (some rollback) (var-get tx-fee)))))
          (map-set rollbacks id {
            id: id,
            rollback: rollback,
            ssn: (unwrap-panic sn)
          })
          (ok true)
        )
      )
      (match (as-contract (contract-call? .call-service send-message to data none (var-get tx-fee)))
        success (ok true)
        error (err error)
      )
    )
  )
)

(define-public (handle-call-message (from (string-ascii 150)) (data (buff 1024)))
  (begin
    (asserts! (is-eq tx-sender (var-get call-svc)) ERR_ONLY_CALL_SERVICE)
    (if (compare-to from (var-get call-svc-net-addr))
      (let ((decoded-data (contract-call? .rlp-decode rlp-to-list data)))
        (let ((id (contract-call? .rlp-decode rlp-decode-uint decoded-data u0)))
          (let ((stored (unwrap-panic (map-get? rollbacks id))))
            (asserts! (compare-to (unwrap-panic (as-max-len? (contract-call? .rlp-decode decode-string data) u150)) (unwrap-panic (as-max-len? (contract-call? .rlp-decode decode-string (get rollback stored)) u150))) ERR_ROLLBACK_MISMATCH)
            (map-delete rollbacks id)
            (print {
              type: "RollbackDataReceived",
              from: from,
              ssn: (get ssn stored),
              rollback: (get rollback stored)
            })
            (ok true)
          )
        )
      )
      (begin
        (print {
          type: "MessageReceived",
          from: from,
          data: data
        })
        (ok true)
      )
    )
  )
)
;;

;; private functions
(define-private (compare-to (base (string-ascii 150)) (value (string-ascii 150)))
  (is-eq (hash160 (unwrap-panic (to-consensus-buff? base))) (hash160 (unwrap-panic (to-consensus-buff? value))))
)
;;