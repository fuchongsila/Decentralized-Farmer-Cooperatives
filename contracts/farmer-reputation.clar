;; Farmer Reputation and Reliability Scoring System
;; Tracks farmer performance metrics including completed tasks, reliability score, and participation history
;; Independent feature with no cross-contract dependencies

;; Error constants
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_INVALID_SCORE (err u102))
(define-constant ERR_ALREADY_RATED (err u103))

;; Farmer reputation profiles: tracks reliability score and task history
(define-map farmer-reputation
  principal
  {
    reliability-score: uint,
    tasks-completed: uint,
    tasks-failed: uint,
    last-updated: uint,
    participation-count: uint
  }
)

;; Peer ratings: farmers can rate each other on a 1-10 scale
(define-map farmer-ratings
  { rater: principal, rated: principal }
  {
    rating: uint,
    comment: (string-ascii 200),
    timestamp: uint
  }
)

;; Initialize a farmer's reputation profile with default values
;; Initial reliability score starts at 50 (medium)
(define-public (initialize-farmer-reputation (farmer principal))
  (let
    (
      (current-block stacks-block-height)
    )
    (map-set farmer-reputation farmer
      {
        reliability-score: u50,
        tasks-completed: u0,
        tasks-failed: u0,
        last-updated: current-block,
        participation-count: u0
      }
    )
    (ok true)
  )
)

;; Record a successfully completed task for a farmer
;; Increases reliability score by 5 points and increments task counter
(define-public (record-task-completion (farmer principal))
  (let
    (
      (current-block stacks-block-height)
      (rep-data (default-to 
        { reliability-score: u50, tasks-completed: u0, tasks-failed: u0, last-updated: current-block, participation-count: u0 }
        (map-get? farmer-reputation farmer)
      ))
    )
    
    (map-set farmer-reputation farmer
      {
        reliability-score: (+ (get reliability-score rep-data) u5),
        tasks-completed: (+ (get tasks-completed rep-data) u1),
        tasks-failed: (get tasks-failed rep-data),
        last-updated: current-block,
        participation-count: (+ (get participation-count rep-data) u1)
      }
    )
    (ok true)
  )
)

;; Record a failed or incomplete task for a farmer
;; Decreases reliability score by 3 points and increments failure counter
(define-public (record-task-failure (farmer principal))
  (let
    (
      (current-block stacks-block-height)
      (rep-data (default-to 
        { reliability-score: u50, tasks-completed: u0, tasks-failed: u0, last-updated: current-block, participation-count: u0 }
        (map-get? farmer-reputation farmer)
      ))
      (new-score (if (>= (get reliability-score rep-data) u3) (- (get reliability-score rep-data) u3) u0))
    )
    
    (map-set farmer-reputation farmer
      {
        reliability-score: new-score,
        tasks-completed: (get tasks-completed rep-data),
        tasks-failed: (+ (get tasks-failed rep-data) u1),
        last-updated: current-block,
        participation-count: (+ (get participation-count rep-data) u1)
      }
    )
    (ok true)
  )
)

;; Submit a rating for another farmer (1-10 scale)
;; One rating per rater-rated pair; updates existing rating if already rated
(define-public (submit-farmer-rating (rated-farmer principal) (rating uint) (comment (string-ascii 200)))
  (let
    (
      (current-block stacks-block-height)
    )
    (asserts! (and (>= rating u1) (<= rating u10)) ERR_INVALID_SCORE)
    (asserts! (not (is-eq tx-sender rated-farmer)) ERR_UNAUTHORIZED)
    
    (map-set farmer-ratings { rater: tx-sender, rated: rated-farmer }
      {
        rating: rating,
        comment: comment,
        timestamp: current-block
      }
    )
    (ok true)
  )
)

;; Get a farmer's current reputation profile
;; Returns None if the farmer has no profile yet
(define-read-only (get-farmer-reputation (farmer principal))
  (map-get? farmer-reputation farmer)
)

;; Get a rating submitted by one farmer for another
;; Returns None if no rating exists between the two farmers
(define-read-only (get-farmer-rating (rater principal) (rated principal))
  (map-get? farmer-ratings { rater: rater, rated: rated })
)

;; Calculate average reliability score for a farmer
;; Returns the reliability score divided by participation count
;; Returns 0 if no participation yet
(define-read-only (get-average-reliability-score (farmer principal))
  (let
    (
      (default-rep { reliability-score: u0, tasks-completed: u0, tasks-failed: u0, last-updated: u0, participation-count: u0 })
      (rep-data (default-to default-rep (map-get? farmer-reputation farmer)))
    )
    (if (> (get participation-count rep-data) u0)
      (/ (get reliability-score rep-data) (get participation-count rep-data))
      u0
    )
  )
)

;; Calculate success rate for a farmer
;; Returns tasks completed / total tasks, or 0 if no tasks
(define-read-only (get-farmer-success-rate (farmer principal))
  (let
    (
      (default-rep { reliability-score: u0, tasks-completed: u0, tasks-failed: u0, last-updated: u0, participation-count: u0 })
      (rep-data (default-to default-rep (map-get? farmer-reputation farmer)))
      (total-tasks (+ (get tasks-completed rep-data) (get tasks-failed rep-data)))
    )
    (if (> total-tasks u0)
      (/ (* (get tasks-completed rep-data) u100) total-tasks)
      u0
    )
  )
)
