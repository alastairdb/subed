;; -*- eval: (buttercup-minor-mode); lexical-binding: t; -*-

(load-file "./tests/undercover-init.el")
(require 'subed)
(require 'subed-ass)

(defvar mock-ass-data
  "[Script Info]
; Script generated by FFmpeg/Lavc58.134.100
ScriptType: v4.00+
PlayResX: 384
PlayResY: 288
ScaledBorderAndShadow: yes

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Default,Arial,16,&Hffffff,&Hffffff,&H0,&H0,0,0,0,0,100,100,0,0,1,1,0,2,10,10,10,0

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
Dialogue: 0,0:00:11.12,0:00:14.00,Default,,0,0,0,,Hello, world!
Dialogue: 0,0:00:14.00,0:00:16.80,Default,,0,0,0,,This is a test.
Dialogue: 0,0:00:17.00,0:00:19.80,Default,,0,0,0,,I hope it works.
")

(defmacro with-temp-ass-buffer (&rest body)
  "Initialize temporary buffer with `subed-ass-mode' and run BODY."
  `(with-temp-buffer
     (subed-ass-mode)
     (progn ,@body)))

(describe "ASS"
  (describe "Getting"
    (describe "the subtitle start/stop time"
      (it "returns the time in milliseconds."
        (with-temp-ass-buffer
         (insert mock-ass-data)
         (subed-jump-to-subtitle-id "0:00:14.00")
         (expect (subed-subtitle-msecs-start) :to-equal (* 14 1000))
         (expect (subed-subtitle-msecs-stop) :to-equal (+ (* 16 1000) 800))))
      (it "returns nil if time can't be found."
        (with-temp-ass-buffer
         (expect (subed-subtitle-msecs-start) :to-be nil)
         (expect (subed-subtitle-msecs-stop) :to-be nil)))
      )
    (describe "the subtitle text"
      (describe "when text is empty"
        (it "and at the beginning with a trailing newline."
          (with-temp-ass-buffer
           (insert mock-ass-data)
           (subed-jump-to-subtitle-text "0:00:11.12")
           (kill-line)
           (expect (subed-subtitle-text) :to-equal "")))))
    (describe "when text is not empty"
      (it "and has no linebreaks."
        (with-temp-ass-buffer
         (insert mock-ass-data)
         (subed-jump-to-subtitle-text "0:00:14.00")
         (expect (subed-subtitle-text) :to-equal "This is a test.")))))
  (describe "Jumping"
    (describe "to current subtitle timestamp"
      (it "can handle different formats of timestamps."
        (with-temp-ass-buffer
         (insert mock-ass-data)
         (expect (subed-jump-to-subtitle-id "00:00:11.120") :to-equal 564)
         (expect (subed-subtitle-msecs-start) :to-equal 11120)))
      (it "returns timestamp's point when point is already on the timestamp."
        (with-temp-ass-buffer
         (insert mock-ass-data)
         (goto-char (point-min))
         (subed-jump-to-subtitle-id "0:00:11.12")
         (expect (subed-jump-to-subtitle-time-start) :to-equal (point))
         (expect (looking-at subed--regexp-timestamp) :to-be t)
         (expect (match-string 0) :to-equal "0:00:11.12")))
      (it "returns timestamp's point when point is on the text."
        (with-temp-ass-buffer
         (insert mock-ass-data)
         (search-backward "test")
         (expect (thing-at-point 'word) :to-equal "test")
         (expect (subed-jump-to-subtitle-time-start) :to-equal 640)
         (expect (looking-at subed--regexp-timestamp) :to-be t)
         (expect (match-string 0) :to-equal "0:00:14.00")))
      (it "returns nil if buffer is empty."
        (with-temp-ass-buffer
         (expect (buffer-string) :to-equal "")
         (expect (subed-jump-to-subtitle-time-start) :to-equal nil))))
    (describe "to specific subtitle by timestamp"
      (it "returns timestamp's point if wanted time exists."
        (with-temp-ass-buffer
         (insert mock-ass-data)
         (goto-char (point-max))
         (expect (subed-jump-to-subtitle-id "0:00:11.12") :to-equal 564)
         (expect (looking-at (regexp-quote "Dialogue: 0,0:00:11.12")) :to-be t)
         (expect (subed-jump-to-subtitle-id "0:00:17.00") :to-equal 694)
         (expect (looking-at (regexp-quote "Dialogue: 0,0:00:17.00")) :to-be t)))
      (it "returns nil and does not move if wanted ID does not exists."
        (with-temp-ass-buffer
         (insert mock-ass-data)
         (goto-char (point-min))
         (search-forward "test")
         (let ((stored-point (point)))
           (expect (subed-jump-to-subtitle-id "0:08:00") :to-equal nil)
           (expect stored-point :to-equal (point))))))
    (describe "to subtitle start time"
      (it "returns start time's point if movement was successful."
        (with-temp-ass-buffer
         (insert mock-ass-data)
         (re-search-backward "world")
         (expect (subed-jump-to-subtitle-time-start) :to-equal 576)
         (expect (looking-at subed--regexp-timestamp) :to-be t)
         (expect (match-string 0) :to-equal "0:00:11.12")))
      (it "returns nil if movement failed."
        (with-temp-ass-buffer
         (expect (subed-jump-to-subtitle-time-start) :to-equal nil))))
    (describe "to subtitle stop time"
      (it "returns stop time's point if movement was successful."
        (with-temp-ass-buffer
         (insert mock-ass-data)
         (re-search-backward "test")
         (expect (subed-jump-to-subtitle-time-stop) :to-equal 651)
         (expect (looking-at subed--regexp-timestamp) :to-be t)
         (expect (match-string 0) :to-equal "0:00:16.80")))
      (it "returns nil if movement failed."
        (with-temp-ass-buffer
         (expect (subed-jump-to-subtitle-time-stop) :to-equal nil))))
    (describe "to subtitle text"
      (it "returns subtitle text's point if movement was successful."
        (with-temp-ass-buffer
         (insert mock-ass-data)
         (goto-char (point-min))
         (expect (subed-jump-to-subtitle-text) :to-equal 614)
         (expect (looking-at "Hello, world!") :to-equal t)
         (forward-line 1)
         (expect (subed-jump-to-subtitle-text) :to-equal 678)
         (expect (looking-at "This is a test.") :to-equal t)))
      (it "returns nil if movement failed."
        (with-temp-ass-buffer
         (expect (subed-jump-to-subtitle-time-stop) :to-equal nil))))
    (describe "to end of subtitle text"
      (it "returns point if subtitle end can be found."
        (with-temp-ass-buffer
         (insert mock-ass-data)
         (goto-char (point-min))
         (expect (subed-jump-to-subtitle-end) :to-be 627)
         (expect (looking-back "Hello, world!") :to-be t)
         (forward-char 2)
         (expect (subed-jump-to-subtitle-end) :to-be 693)
         (expect (looking-back "This is a test.") :to-be t)
         (forward-char 2)
         (expect (subed-jump-to-subtitle-end) :to-be 760)
         (expect (looking-back "I hope it works.") :to-be t)))
      (it "returns nil if subtitle end cannot be found."
        (with-temp-ass-buffer
         (expect (subed-jump-to-subtitle-end) :to-be nil)))
      (it "returns nil if point did not move."
        (with-temp-ass-buffer
         (insert mock-ass-data)
         (subed-jump-to-subtitle-text "0:00:11.12")
         (subed-jump-to-subtitle-end)
         (expect (subed-jump-to-subtitle-end) :to-be nil)))
      (it "works if text is empty."
        (with-temp-ass-buffer
         (insert mock-ass-data)
         (subed-jump-to-subtitle-text "00:00:11.12")
         (kill-line)
         (backward-char)
         (expect (subed-jump-to-subtitle-end) :to-be 614))))
    (describe "to next subtitle ID"
      (it "returns point when there is a next subtitle."
        (with-temp-ass-buffer
         (insert mock-ass-data)
         (subed-jump-to-subtitle-id "00:00:11.12")
         (expect (subed-forward-subtitle-id) :to-be 628)
         (expect (looking-at (regexp-quote "Dialogue: 0,0:00:14.00")) :to-be t)))
      (it "returns nil and doesn't move when there is no next subtitle."
        (with-temp-ass-buffer
         (expect (thing-at-point 'word) :to-equal nil)
         (expect (subed-forward-subtitle-id) :to-be nil))
        (with-temp-ass-buffer
         (insert mock-ass-data)
         (subed-jump-to-subtitle-text "0:00:17.00")
         (expect (subed-forward-subtitle-id) :to-be nil))))
    (describe "to previous subtitle ID"
      (it "returns point when there is a previous subtitle."
        (with-temp-ass-buffer
         (insert mock-ass-data)
         (subed-jump-to-subtitle-text "00:00:14.00")
         (expect (subed-backward-subtitle-id) :to-be 564)))
      (it "returns nil and doesn't move when there is no previous subtitle."
        (with-temp-ass-buffer
         (expect (subed-backward-subtitle-id) :to-be nil))
        (with-temp-ass-buffer
         (insert mock-ass-data)
         (subed-jump-to-subtitle-id "00:00:11.12")
         (expect (subed-backward-subtitle-id) :to-be nil))))
    (describe "to next subtitle text"
      (it "returns point when there is a next subtitle."
        (with-temp-ass-buffer
         (insert mock-ass-data)
         (subed-jump-to-subtitle-id "00:00:14.00")
         (expect (subed-forward-subtitle-text) :to-be 744)
         (expect (thing-at-point 'word) :to-equal "I")))
      (it "returns nil and doesn't move when there is no next subtitle."
        (with-temp-ass-buffer
         (goto-char (point-max))
         (insert (concat mock-ass-data "\n\n"))
         (subed-jump-to-subtitle-id "00:00:17.00")
         (expect (subed-forward-subtitle-text) :to-be nil))))
    (describe "to previous subtitle text"
      (it "returns point when there is a previous subtitle."
        (with-temp-ass-buffer
         (insert mock-ass-data)
         (subed-jump-to-subtitle-id "00:00:14.00")
         (expect (subed-backward-subtitle-text) :to-be 614)
         (expect (thing-at-point 'word) :to-equal "Hello")))
      (it "returns nil and doesn't move when there is no previous subtitle."
        (with-temp-ass-buffer
         (insert mock-ass-data)
         (goto-char (point-min))
         (subed-forward-subtitle-time-start)
         (expect (looking-at (regexp-quote "0:00:11.12")) :to-be t)
         (expect (subed-backward-subtitle-text) :to-be nil)
         (expect (looking-at (regexp-quote "0:00:11.12")) :to-be t))))
    (describe "to next subtitle end"
      (it "returns point when there is a next subtitle."
        (with-temp-ass-buffer
         (insert mock-ass-data)
         (subed-jump-to-subtitle-text "00:00:14.00")
         (expect (thing-at-point 'word) :to-equal "This")
         (expect (subed-forward-subtitle-end) :to-be 760)))
      (it "returns nil and doesn't move when there is no next subtitle."
        (with-temp-ass-buffer
         (insert (concat mock-ass-data "\n\n"))
         (subed-jump-to-subtitle-text "00:00:17.00")
         (expect (subed-forward-subtitle-end) :to-be nil))))
    (describe "to previous subtitle end"
      (it "returns point when there is a previous subtitle."
        (with-temp-ass-buffer
         (insert mock-ass-data)
         (subed-jump-to-subtitle-id "00:00:14.00")
         (expect (subed-backward-subtitle-end) :to-be 627)))
      (it "returns nil and doesn't move when there is no previous subtitle."
        (with-temp-ass-buffer
         (insert mock-ass-data)
         (goto-char (point-min))
         (subed-forward-subtitle-id)
         (expect (looking-at (regexp-quote "Dialogue: 0,0:00:11.12")) :to-be t)
         (expect (subed-backward-subtitle-text) :to-be nil)
         (expect (looking-at (regexp-quote "Dialogue: 0,0:00:11.12")) :to-be t))))
    (describe "to next subtitle start time"
      (it "returns point when there is a next subtitle."
        (with-temp-ass-buffer
         (insert mock-ass-data)
         (subed-jump-to-subtitle-id "00:00:14.00")
         (expect (subed-forward-subtitle-time-start) :to-be 706)))
      (it "returns nil and doesn't move when there is no next subtitle."
        (with-temp-ass-buffer
         (insert mock-ass-data)
         (subed-jump-to-subtitle-id "00:00:17.00")
         (let ((pos (point)))
           (expect (subed-forward-subtitle-time-start) :to-be nil)
           (expect (point) :to-be pos)))))
    (describe "to previous subtitle stop"
      (it "returns point when there is a previous subtitle."
        (with-temp-ass-buffer
         (insert mock-ass-data)
         (subed-jump-to-subtitle-id "00:00:14.00")
         (expect (subed-backward-subtitle-time-stop) :to-be 587)))
      (it "returns nil and doesn't move when there is no previous subtitle."
        (with-temp-ass-buffer
         (insert mock-ass-data)
         (goto-char (point-min))
         (subed-forward-subtitle-id)
         (expect (subed-backward-subtitle-time-stop) :to-be nil)
         (expect (looking-at (regexp-quote "Dialogue: 0,0:00:11.12")) :to-be t))))
    (describe "to next subtitle stop time"
      (it "returns point when there is a next subtitle."
        (with-temp-ass-buffer
         (insert mock-ass-data)
         (subed-jump-to-subtitle-id "00:00:14.00")
         (expect (subed-forward-subtitle-time-stop) :to-be 717)))
      (it "returns nil and doesn't move when there is no next subtitle."
        (with-temp-ass-buffer
         (insert mock-ass-data)
         (subed-jump-to-subtitle-id "00:00:17.00")
         (let ((pos (point)))
           (expect (subed-forward-subtitle-time-stop) :to-be nil)
           (expect (point) :to-be pos))))))

  (describe "Setting start/stop time"
    (it "of subtitle should set it."
      (with-temp-ass-buffer
       (insert mock-ass-data)
       (subed-jump-to-subtitle-id "00:00:14.00")
       (subed-set-subtitle-time-start (+ (* 15 1000) 400))
       (expect (subed-subtitle-msecs-start) :to-be (+ (* 15 1000) 400)))))

  (describe "Inserting a subtitle"
    (describe "in an empty buffer"
      (describe "before the current subtitle"
        (it "creates an empty subtitle when passed nothing."
          (with-temp-ass-buffer
           (subed-prepend-subtitle)
           (expect (buffer-string) :to-equal (concat "Dialogue: 0,0:00:00.00,0:00:01.00,Default,,0,0,0,,\n"))))
        (it "creates a subtitle with a start time."
          (with-temp-ass-buffer
           (subed-prepend-subtitle nil 12340)
           (expect (buffer-string) :to-equal (concat "Dialogue: 0,0:00:12.34,0:00:13.34,Default,,0,0,0,,\n"))))
        (it "creates a subtitle with a start time and stop time."
          (with-temp-ass-buffer
           (subed-prepend-subtitle nil 60000 65000) 
           (expect (buffer-string) :to-equal "Dialogue: 0,0:01:00.00,0:01:05.00,Default,,0,0,0,,\n")))
        (it "creates a subtitle with start time, stop time and text."
          (with-temp-ass-buffer
           (subed-prepend-subtitle nil 60000 65000 "Hello world")
           (expect (buffer-string) :to-equal "Dialogue: 0,0:01:00.00,0:01:05.00,Default,,0,0,0,,Hello world\n"))))
      (describe "after the current subtitle"
        (it "creates an empty subtitle when passed nothing."
          (with-temp-ass-buffer
           (subed-append-subtitle)
           (expect (buffer-string) :to-equal (concat "Dialogue: 0,0:00:00.00,0:00:01.00,Default,,0,0,0,,\n"))))
        (it "creates a subtitle with a start time."
          (with-temp-ass-buffer
           (subed-append-subtitle nil 12340)
           (expect (buffer-string) :to-equal (concat "Dialogue: 0,0:00:12.34,0:00:13.34,Default,,0,0,0,,\n"))))
        (it "creates a subtitle with a start time and stop time."
          (with-temp-ass-buffer
           (subed-append-subtitle nil 60000 65000) 
           (expect (buffer-string) :to-equal "Dialogue: 0,0:01:00.00,0:01:05.00,Default,,0,0,0,,\n")))
        (it "creates a subtitle with start time, stop time and text."
          (with-temp-ass-buffer
           (subed-append-subtitle nil 60000 65000 "Hello world")
           (expect (buffer-string) :to-equal "Dialogue: 0,0:01:00.00,0:01:05.00,Default,,0,0,0,,Hello world\n"))))))
  (describe "in a non-empty buffer"
    (describe "before the current subtitle"
      (describe "with point on the first subtitle"
        (it "creates the subtitle before the current one."
          (with-temp-ass-buffer
           (insert mock-ass-data)
           (subed-jump-to-subtitle-time-stop)
           (subed-prepend-subtitle)
           (expect (buffer-substring (line-beginning-position) (line-end-position))
                   :to-equal (concat "Dialogue: 0,0:00:00.00,0:00:01.00,Default,,0,0,0,,")))))
      (describe "with point on a middle subtitle"
        (it "creates the subtitle before the current one."
          (with-temp-ass-buffer
           (insert mock-ass-data)
           (subed-jump-to-subtitle-time-stop "0:00:14.00")
           (subed-prepend-subtitle)
           (expect (buffer-substring (line-beginning-position) (line-end-position))
                   :to-equal (concat "Dialogue: 0,0:00:00.00,0:00:01.00,Default,,0,0,0,,"))
           (forward-line 1)
           (beginning-of-line)
           (expect (looking-at "Dialogue: 0,0:00:14.00")))))
      )
    (describe "after the current subtitle"
      (describe "with point on a subtitle"
        (it "creates the subtitle after the current one."
          (with-temp-ass-buffer
           (insert mock-ass-data)
           (subed-jump-to-subtitle-time-stop "0:00:14.00")
           (subed-append-subtitle)
           (expect (buffer-substring (line-beginning-position) (line-end-position))
                   :to-equal (concat "Dialogue: 0,0:00:00.00,0:00:01.00,Default,,0,0,0,,"))
           (forward-line -1)
           (expect (subed-subtitle-msecs-start) :to-be 14000))))))
  (describe "Killing a subtitle"
    (it "removes the first subtitle."
      (with-temp-ass-buffer
       (insert mock-ass-data)
       (subed-jump-to-subtitle-text "0:00:11.12")
       (subed-kill-subtitle)
       (expect (subed-subtitle-msecs-start) :to-be 14000)
       (forward-line -1)
       (beginning-of-line)
       (expect (looking-at "Format: Layer")))))
  (it "removes it in between."
    (with-temp-ass-buffer
     (insert mock-ass-data)
     (subed-jump-to-subtitle-text "00:00:14.00")
     (subed-kill-subtitle)
     (expect (subed-subtitle-msecs-start) :to-be 17000)))
  (it "removes the last subtitle."
    (with-temp-ass-buffer
     (insert mock-ass-data)
     (subed-jump-to-subtitle-text "00:00:17.00")
     (subed-kill-subtitle)
     (expect (subed-subtitle-msecs-start) :to-be 14000)))
  (describe "Converting msecs to timestamp"
    (it "uses the right format"
      (with-temp-ass-buffer
       (expect (subed-msecs-to-timestamp 1410) :to-equal "0:00:01.41")))))
