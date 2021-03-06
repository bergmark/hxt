{- |
   Module     : RDFNormalize 
   Author     : Manuel Ohlendorf  

   Maintainer : Manuel Ohlendorf
   Stability  : experimental
   Portability: portable
   Version    :

Contains all normalisation arrows and exports the main entry point to them
-}

module RDFNormalize  (normalizeRDF)
where
import Char
import Text.XML.HXT.Arrow
import RDFFunctions
import Maybe
import Text.XML.HXT.DOM.Util


-- -------------------------------------------------------------
-- ***** NORMALISATION ****
-- -------------------------------------------------------------

-- | The normalisation arrow. 
-- Creates a normalised RDF\/XML document where several abbreviations have been removed\/normalised.
-- Not every abbreviation is supported right now.
normalizeRDF :: IOSArrow XmlTree XmlTree
normalizeRDF = processChildren $ 
               seqA [changeBase
                    ,mkAbsoluteURIs
                    ,convertToUtf
                    ,processContainer
                    ,processTypedElem
                    ,generateDescElem
                    ,reifyStatement
                    ,generateNodeID
                    ,processChildren (multi isNodeElem)
                    ,deleteDuplicate
                    ,processPropertyAttr -- all Desc ELements must be generated and unfolded befor generating objects
                    ]

-- | removes duplicate node elements, generated by the unfolding
-- every information of this elements is copied to the element above
deleteDuplicate :: (ArrowXml a) => a XmlTree XmlTree
deleteDuplicate 
    = processTopDown (
        (processChildren( (addAttrl (getChildren >>> getAttrl) >>> setChildren []) 
                           `when` 
                          (getChildren >>> isNodeElem))
        )`when` (isNodeElem >>> (deep isNodeElem) ) --`when` (isNodeElem >>> (getChildren>>>getChildren >>> isNodeElem) ))
                     )


-- | Node elements which do not have the name rdf:Description, are extended by the predicate rdf:type and the subject
-- name as value.
processTypedElem ::  (ArrowXml a) => a XmlTree XmlTree
processTypedElem 
  = processTopDown (
      (insertChildrenAt 0 typeElem >>> setElemName rdf_Description)
      `when`  
      ((neg isEmptyElem >>> isTypedNodeElem) `orElse` (isTypedNodeElem >>> nonRDFAttributes)) )
    
    where 
    typeElem 
      = mkElement rdf_type (qattr rdf_resource (getUniversalUri >>> mkText)) none
    
    isTypedNodeElem 
      = isElem  >>> (hasQAttr rdf_nodeID `orElse` hasQAttr rdf_about) >>> neg (hasQName rdf_Description)
    
    nonRDFAttributes = getAttrl >>> neg ( hasQName rdf_about 
                                          `orElse` hasQName rdf_nodeID 
                                          `orElse` hasName "xml:lang"
                                          `orElse` hasQName rdf_ID)

-- | Deals with reification elements. Is not able to process every kind of reification case, yet.
reifyStatement :: IOSArrow XmlTree XmlTree
reifyStatement = processTopDown((catA[this, statement, subject, predicate, object] >>> processChildren (removeQAttr rdf_ID)) 
                                 `when`
                                 (isElem >>> (hasQAttr rdf_about) >>> getChildren >>> hasQAttr rdf_ID))
                                    where
                                    aboutValue = ((getBaseURI >>> arr(++"#")) &&& (getChildren>>>getQAttrValue rdf_ID)) >>> arr(uncurry (++))
                                
                                    statement = generateReifyNode rdf_type rdf_resource (txt (universalUri rdf_Statement ))
                                    subject   = generateReifyNode rdf_subject rdf_resource (getQAttrValue rdf_about >>> mkText)
                                    predicate = generateReifyNode rdf_predicate rdf_resource (getChildren >>>getUniversalUri >>> mkText)
                                    object = ifA (getChildren >>> hasQAttr rdf_resource) 
                                                             (generateReifyNode rdf_object rdf_resource (getChildren >>>getChildren))
                                                             (mkElement rdf_Description (qattr rdf_about (aboutValue >>> mkText)) (mkElement rdf_object none (getChildren>>>getChildren)))

                                    generateReifyNode theType objectType theObj = mkElement rdf_Description (qattr rdf_about (aboutValue >>> mkText)) (mkElement theType (qattr objectType theObj) none) 

-- | Replaces every rdf:li element with a unique number
processContainer :: IOSArrow XmlTree XmlTree
processContainer = processTopDown((arr setElemName $< counterLi)
                                     `when`
                                     (isElem >>> hasQName rdf_li))
                                      where
                                      counterLi = getCounter "li_counter"
                                                  >>> (arr ('_':)) 
                                                  >>> arr((flip mkNsName) $ namespaceRDF)  
 

-- | generates blank node identifiers 
-- furthermore, the fragment identifers are processed here.
generateNodeID :: IOSArrow XmlTree XmlTree
generateNodeID
    = processTopDown (choiceA   [choice1 :-> addAttrl (qattr rdf_nodeID (getCounter "node_id">>>(arr("genid"++)) >>> mkText))   -- id erzeugen und zustand verändern
                                ,(isElem >>> hasQAttr rdf_ID) :-> ((addAttrl (qattr rdf_about attrValue) )>>>removeQAttr rdf_ID) 
                                ,this:-> this
                              ]
                     )
                     where 
                     choice1 = ( isElem >>> hasQName rdf_Description >>> neg ( hasQAttr rdf_nodeID `orElse` hasQAttr rdf_about `orElse` hasQAttr rdf_ID))

                     --creates an absolut from the input                        
                     attrValue = getQAttrValue rdf_ID >>> arr('#':)>>> mkAbsURI >>> mkText

-- | processing of xml:base
changeBase :: IOSArrow XmlTree XmlTree
changeBase
        = processTopDownWithAttrl ( 
            (perform (getAttrValue "xml:base" >>> changeBaseURI)) 
            `when` (isElem >>> hasAttr "xml:base")
            )


-- | generate a simple counter and returns its value as String
getCounter :: String -> IOSArrow b String
getCounter name   
        = arr genNewId                      
     $<
     getParamInt 1 name       -- default start wert 0
   where
   genNewId :: Int -> IOSArrow b String
   genNewId i
        = setParamInt name (i+1)              -- wird hier beim ersten aufruf in den zustand geschrieben
            >>>
            constA (show i)



-- | generates node elements for property-and-node elements.
generateDescElem :: (ArrowXml a) => a XmlTree XmlTree
generateDescElem 
    = processTopDown (replaceChildren (mkElement rdf_Description none getChildren) 
                      `when` hasResourceParseType )


{- generates Property and Object for Property attributes in subject elements-}
processPropertyAttr :: (ArrowXml a) => a XmlTree XmlTree
processPropertyAttr 
    = processTopDown (
            insertChildrenAt 0 propertyElements 
            `when` isNodeElem )

propertyElements :: (ArrowXml a) => a XmlTree XmlTree
propertyElements
    = getAttrl 
      >>> neg ( hasQName rdf_about 
                `orElse` hasQName rdf_nodeID
                `orElse` hasName "xml:lang"
                `orElse` hasQName rdf_ID )
      >>> arr mkqelem $<<< getQName &&& listA none &&& (listA (constA getChildren))


-- | changes every relative URI to the absolute uri.                                            
mkAbsoluteURIs :: IOSArrow XmlTree XmlTree
mkAbsoluteURIs = processChildren (mkAbs `when` isElem)
      where
      mkAbs = mkAbsURIs $< getBaseURI 

mkAbsURIs   :: String -> IOSArrow XmlTree XmlTree
mkAbsURIs base
        = processTopDown editURIs       -- edit all refs in documnt
        where

        -- build the edit filter from the list of element-attribute names
        editURIs = seqA . map mkAbs $ rdfAttrs
      
        -- list of attributes which can have relative uris
        rdfAttrs = [ rdf_about,rdf_datatype,rdf_resource]

        -- change the reference in attribute attrName of element elemName

        mkAbs attrName = processAttrl ( changeAttrValue (mkAbsURIString base)
                `when`
                hasQName attrName
                )

-- | compute an absolute URI, if not possible leave URI unchanged
mkAbsURIString  :: String -> String -> String
mkAbsURIString base uri
    = fromMaybe uri . expandURIString uri $ base



-- | converts every non US-ASCII character to the encoded UNICODE variant
convertToUtf :: (ArrowXml a) => a XmlTree XmlTree
convertToUtf
        = processTopDown editToUtf
      where editToUtf = changeText toUtf `when` isText

toUtf :: [Char] -> [Char]
toUtf = concatMap charToUtf

charToUtf :: Char -> String
charToUtf c
  | ord c < 0x80  = [c]
  | otherwise = "\\u00" ++ charToHexString c

{-hexChar :: Int -> String
hexChar i | i < 0 = hexChar (i + 2^16)
hexChar i =  toHex (i `div` 256) ++ toHex (i `mod` 256)

toHex :: Int -> [Char]
toHex i = [toHexDigit (i `div` 16), toHexDigit (i `mod` 16)]

toHexDigit :: Int -> Char
toHexDigit x
  | x < 10= chr ((ord '0')+x)
  | otherwise= chr ((ord 'A')+x-10)-}
