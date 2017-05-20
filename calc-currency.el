;;; calc-currency.el --- Fetches currency exchange rates for Calc

;; Author: J. W. Smith <jwsmith2spam at gmail dot com>
;; Keywords: calc, currency, exchange
;; Time-stamp: <2017-05-20 15:35:10 jws>

;;; Notes:

(require 'cl)   ;; for the loop macro

(require 'calc-currency-db)
(require 'calc-currency-utils)
(require 'calc-currency-ecb)

;; Where to save the exchange rates to
(defcustom calc-currency-exchange-rates-file
  (expand-file-name "calc-currency-rates.el" user-emacs-directory)
  "Where calc-currency saves the latest exchange rates to."
  :group 'calc-currency
  :type 'string)

;; How often to check for exchange rates
(defvar *exchange-rates-update-interval* 5)

;; The currency to use as the base for the final table
(defvar *base-currency* 'USD)

(defun build-currency-unit-table ()
  "Take the alist from `process-currency-rates` and transform it into a list structured like `math-additional-units`."
  (let* ((rate-table (calc-currency-ecb-process-rates))
         (base-rate (assqv *base-currency* rate-table))
         (base-desc (assqv *base-currency* *currency-db*))
         (rate-table-mod (assq-delete-all *base-currency* rate-table)))
    (cons (list *base-currency* nil base-desc)
          (loop for rate in rate-table
                collect (list
                         (car rate)
                         (format "%S / %f" *base-currency* (/ (cdr rate) base-rate))
                         (assqv (car rate) *currency-db*))))))

;; necessary for write-currency-unit-table to work properly
(setq-local eval-expression-print-length nil)
(defun write-currency-unit-table ()
  "Writes the exchange rate table to a file."
  (write-region
   (pp (build-currency-unit-table))
   nil
   calc-currency-exchange-rates-file))

(defun check-currency-unit-table ()
  "Check to see if the exchange rates table exists, or if it is up to date.
If it is not, fetch new data and write a new exchange rate table."
  (if (or (not (file-readable-p calc-currency-exchange-rates-file))
          (> (calc-currency-utils-file-age calc-currency-exchange-rates-file) *exchange-rates-update-interval*))
      (progn
        (write-currency-unit-table)
        (message "Fetched new exchange rates!"))))

(defun read-currency-unit-table ()
  "Reads in the exchange rates table."
  (with-temp-buffer
    (insert-file-contents calc-currency-exchange-rates-file)
    (read (buffer-string))))

;; FIXME I'll go back and try the following code:
;;  - if unit exists in math-additional-units, update that entry
;;  - otherwise, add unit

;; FIXME This probably isn't the best way to handle this!
(defun calc-undefine-unit-if-exists (unit)
  "Deletes a unit from `math-additional-units` if it exists."
  (condition-case nil
      (calc-undefine-unit unit)
    (error nil)))

;; FIXME And this probably isn't the best way to handle this!
(defun calc-currency-load ()
  (progn
    (check-currency-unit-table)
    (let ((currency-unit-table (read-currency-unit-table)))
      ;; For each unit of currency, undefine it in math-additional-units
      (loop for unit in currency-unit-table
            do (calc-undefine-unit-if-exists (car unit)))

      ;; Then, add math-standard-units to the units table
      (setq math-additional-units (append math-additional-units (read-currency-unit-table))
            math-units-table nil))))

(provide 'calc-currency)
