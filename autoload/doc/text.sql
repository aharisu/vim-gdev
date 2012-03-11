
;;;;;
;;@type cmd
;;@@parse-relative #f


;;;;;
;;@type Class
;;@name <sql-parse-error>
;;@description SQLパーズエラーを示すコンディション。<error>を継承。
;;元のSQL文字列を保持。
;;

;;;;;
;;@type Function
;;@name sql-tokenize
;;@description SQL文sql-stringをトークン列に分解します。返り値はトークンのリス
;;トで、各トークンは以下の形式のひとつで表現されます。
;;
;;example:
;;  <symbol>              特殊区切り子、以下のどれか
;;                        + - * / < = > <> <= >= ||
;;  <character>           特殊区切り子、以下のどれか
;;                        #\, #\. #\( #\) #\;
;;  <string>              通常の識別子
;;  (delimited <string>)  区切られた識別子
;;  (parameter <num>)     位置パラメータ (?)
;;  (parameter <string>)  名前つきパラメータ (:foo)
;;  (string    <string>)  文字列リテラル
;;  (number    <string>)  数値リテラル
;;  (bitstring <string>)  バイナリ文字列  <string> は "01101" な感じ
;;  (hexstring <string>)  Binary string.  <string> は "3AD20" な感じ
;;
;;トークンに分解できない文字列がくると<sql-parse-error>コンディショ
;;ンがあがります。
;;
;;@param sql-string 

