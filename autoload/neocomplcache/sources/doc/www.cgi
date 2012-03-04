
;;;;;
;;@type cmd
;;@@parse-relative #f

  
;;;;;
;;@type Parameter
;;@name cgi-temporary-files

;;;;;
;;@type Function
;;@name cgi-add-temporary-file
;;@param filename 

;;;;;
;;@type Function
;;@name cgi-main
;;@param proc 
;;@param :key 
;;@param on-error 
;;@param merge-cookies 
;;@param output-proc 
;;@param part-handlers 

;;;;;
;;@type Parameter
;;@name cgi-output-character-encoding
;;@param :optional 
;;@param encoding 

;;;;;
;;@type Function
;;@name cgi-header
;;@param :key 
;;@param status 
;;@param content-type 
;;@param location 
;;@param cookies 

;;;;;
;;@type Function
;;@name cgi-get-parameter
;;@param name 
;;@param params 
;;@param :key 
;;@param :default 
;;@param :list 
;;@param :convert 

;;;;;
;;@type Function
;;@name cgi-parse-parameters
;;@param :key 
;;@param :query-string 
;;@param :merge-cookies 
;;@param :part-handlers 

;;;;;
;;@type Function
;;@name cgi-get-metavariable
;;@param name 

;;;;;
;;@type Parameter
;;@name cgi-metavariables
;;@param :optional 
;;@param metavariables 

