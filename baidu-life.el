(require 'cl)
(require 'url)
(defgroup baidu-life nil
  "爱生活,爱百度"
  :prefix "baidu-life-")

(defcustom baidu-life-API-KEY ""
  "apikey"
  :group 'baidu-life)

(defmacro baidu-life--with-api-key (api-key &rest body)
  (declare (indent defun))
  (let ((apikey (cond ((stringp api-key)
                       api-key)
                      ((symbolp api-key)
                       (symbol-value api-key))
                      (t (error "not valid api-key")))))
    `(let ((url-request-extra-headers
            ',(cons `("apikey" . ,apikey) url-request-extra-headers)))
       ,@body)))

(cl-defun baidu-life--retrieve-url-synchronously (url args &optional (type 'POST ))
  (let* ((url-request-method (if (eq 'POST type)
                                 "POST"
                               "GET"))
         (url-request-data
          (mapconcat (lambda (arg)
                       (concat (url-hexify-string (format "%s" (car arg)))
                               "="
                               (url-hexify-string (format "%s" (cdr arg)))))
                     args
                     "&"))
         (url-request-extra-headers
          (cons '("Content-Type" . "application/x-www-form-urlencoded")
                url-request-extra-headers))
         (url (if (eq 'POST type)
                  url
                (concat url "?" url-request-data))))
    (url-retrieve-synchronously url)))

(cl-defun baidu-life--json-read-from-url (url args &optional (type 'POST))
  (let (charset
        json-string
        json-object)
    (with-current-buffer (baidu-life--with-api-key baidu-life-API-KEY
                           (baidu-life--retrieve-url-synchronously url args type))
      (goto-char (point-min))
      (when (search-forward "charset=" nil t)
        (setq charset (intern (downcase (buffer-substring-no-properties (point) (progn (end-of-line)
                                                                                       (point)))))))
      (goto-char (point-min))
      (search-forward-regexp "^$")
      (setq json-string (buffer-substring (point) (point-max)))
      (when charset
        (setq json-string (decode-coding-string json-string charset)))
      (setq json-object (json-read-from-string json-string))
      (kill-buffer)
      json-object)))


(defun baidu-life-get-weather (&optional location)
  "根据`LOCATION'获取天气信息"
  (interactive)
  (let* ((location (or location (read-string "您想查询那座城市的天气,请输入对应的拼音:")))
         (weather-alist (baidu-life--json-read-from-url "http://apis.baidu.com/apistore/weatherservice/weather"
                                                        `((citypinyin . ,location)) 'GET ))
         (ret-data (cdr (assoc 'retData weather-alist))))
    (format "%s:%s" (cdr (assoc 'weather ret-data))
            (cdr (assoc 'WS ret-data)))))
;; (baidu-life-get-weather "dongguan") => 阴:3-4级(10~17m/h)

(defun baidu-life-get-mobile-location (&optional phone)
  "获取手机号码`PHONE'的开户地"
  (interactive)
  (let* ((phone (or phone (read-string "请待查询的手机号码:")))
         (result-alist (baidu-life--json-read-from-url "http://apis.baidu.com/showapi_open_bus/mobile/find"
                                                       `((num . ,phone)) 'GET))
         (ret-data (cdr (assoc 'showapi_res_body result-alist))))
    (format "%s-%s%s"
            (cdr (assoc 'name ret-data))
            (cdr (assoc 'prov ret-data))
            (cdr (assoc 'city ret-data)))))
;; (baidu-life-get-mobile-location "13570494314") => 中国移动-广东广州

(defun baidu-life-ipsearch (&optional ip)
  "获取`IP'位置信息"
  (interactive)
  (let* ((ip (or ip (read-string "请待查询的IP:")))
         (result-alist (baidu-life--json-read-from-url "http://apis.baidu.com/chazhao/ipsearch/ipsearch"
                                                       `((ip . ,ip)) 'GET))
         (ret-data (cdr (assoc 'data result-alist))))
    (format "%s-%s/%s/%s"
            (cdr (assoc 'operator ret-data))
            (cdr (assoc 'country ret-data))
            (cdr (assoc 'province ret-data))
            (cdr (assoc 'city ret-data)))))
;; (baidu-life-ipsearch "14.17.34.189") => 电信-China/广东省/深圳市

(defun baidu-life-idservice (&optional id)
  "获取身份证号`ID'信息"
  (interactive)
  (let* ((id (or id (read-string "请输入待查询的身份证号:")))
         (result-alist (baidu-life--json-read-from-url "http://apis.baidu.com/apistore/idservice/id"
                                                       `((id . ,id)) 'GET))
         (ret-data (cdr (assoc 'retData result-alist))))
    (format "性别:%s 出生日期:%s 地址:%s"
            (cdr (assoc 'sex ret-data))
            (cdr (assoc 'birthday ret-data))
            (cdr (assoc 'address ret-data)))))
;; (baidu-life-idservice "420984198704207896") => 性别:M 出生日期:1987-04-20 地址:湖北省孝感市汉川市

(defun baidu-life-md5decode (&optional md5)
  "破解`MD5'"
  (interactive)
  (let* ((md5 (or md5 (read-string "请输入待破解的MD5:")))
         (result-alist (baidu-life--json-read-from-url "http://apis.baidu.com/chazhao/md5decod/md5decod"
                                                       `((md5 . ,md5)) 'GET))
         (ret-data (cdr (assoc 'data result-alist))))
    (cdr (assoc 'md5_src ret-data))))

;; (baidu-life-md5decode "b035b895aae7ea345897cac146a9eee3369c9ef1") => fdsfejfkddl



(defun baidu-life-waybillnotrace (&optional expresscode billno)
  "查询快递信息

`EXPRESSCODE'为快递公司代码. （圆通：YT，申通：ST，中通：ZT，邮政EMS: YZEMS，天天：TT，优速：YS，快捷：KJ，全峰：QF，增益：ZY）
`billno'为快递公司的订单号."
  (interactive)
  (let* ((expresscode (or expresscode (read-string "请输入快递公司代号:")))
         (billno (or billno (read-string "请输入订单号:")))
         (result-alist (baidu-life--json-read-from-url "http://apis.baidu.com/ppsuda/waybillnoquery/waybillnotrace"
                                                       `((expresscode . ,expresscode)
                                                         (billno . ,billno)) 'GET))
         (result-alist (elt (cdr (assoc 'data result-alist)) 0))
         (trace-array (cdr (assoc 'wayBills result-alist)))
         (trace-list (mapcar (lambda (trace-alist)
                             (format "%s-%s"
                                     (cdr (assoc 'time trace-alist))
                                     (cdr (assoc 'processInfo trace-alist))))
                           trace-array)))
    (mapconcat 'identity trace-list "\n")))

;; (baidu-life-waybillnotrace "YT" "805121891484")
;; =>
;; 2015-11-23 19:47:38.0 CST-广东省珠海市唐家金鼎公司 签收人: 本人签收 已签收
;; 2015-11-21 09:00:29.0 CST-广东省珠海市唐家金鼎公司 派件人: 赵凯 派件中
;; 2015-11-21 01:52:31.0 CST-广东省珠海市公司 邓亮 已发出
;; 2015-11-20 21:49:26.0 CST-江门转运中心公司 李嘉欣 已发出
;; 2015-11-19 23:33:03.0 CST-福建省漳州市公司 何美玉 已打包
;; 2015-11-19 20:38:49.0 CST-福建省漳州市公司 取件人: 欧阳慧娇 已收件


(provide 'baidu-life)

;;; baidu-life ends here