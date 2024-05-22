;; CallServiceReceiver Trait
(define-trait call-service-receiver-trait
  (
    ;; Handle the call message received from the source chain
    ;; Only called from the Call Message Service
    (handle-call-message ((string-ascii 150) (buff 1024) (list 50 (string-ascii 150))) (response bool uint))
  )
)