module namespace check = "http://www.w3.org/2010/09/qt-fots-catalog/check";
import module namespace pair='http://www.basex.org/pair'
    at 'pair.xqm';

import module namespace ser = 'http://www.basex.org/serialize'
  at 'serialize.xqm';

declare function check:result(
  $res as item()*,
  $result as element()
) as element()? {
  let $err := check:res($res, $result)
  return if(empty($err)) then () else
    <out>
      <result>{ser:serialize($res)}</result>
      <errors>{
        map(function($e){ <error>{$e}</error> }, $err)
      }</errors>
    </out>
};

declare function check:error(
  $code as xs:QName,
  $error as xs:string,
  $result as element()
) as element()? {
  let $err := check:err($code, $error, $result)
  return if(empty($err)) then () else
    <out>
      <result>Error: {concat('[', $code, '] ', $error)}</result>
      <errors>{
        map(function($e){ <error>{$e}</error> }, $err)
      }</errors>
    </out>
};

declare function check:res(
  $res as item()*,
  $result as element()
) as xs:string* {
  let $test := local-name($result)
  return switch($test)
    case 'all-of'
      return map(check:res($res, ?), $result/*)
    case 'any-of'
      return check:any-of($res, $result)
    case 'assert-eq'
      return check:assert-eq($res, $result)
    case 'assert-type'
      return check:assert-type($res, $result)
    case 'assert-string-value'
      return check:assert-string-value($res, $result)
    case 'assert-true'
      return check:assert-bool($res, $result, true())
    case 'assert-false'
      return check:assert-bool($res, $result, false())
    case 'assert-deep-eq'
      return check:assert-deep-eq($res, $result)
    case 'assert-serialization'
      return check:assert-serialization($res, $result)
    case 'assert-permutation'
      return check:assert-permutation($res, $result)
    case 'assert'
      return check:assert($res, $result)
    case 'assert-count' 
      return
        let $count := count($res),
            $exp   := xs:integer($result)
        return if($count eq $exp) then ()
          else concat('Expected ', $exp, ' items, found ', $count, '.')
    case 'assert-empty'
      return if(empty($res)) then () else 'Result is not empty.'
    case 'error'
      return concat('Expected Error [', $result/@code, ']')
    default return error(
      fn:QName('http://www.w3.org/2005/xqt-errors', 'FOTS9999'),
        concat('Unknown assertion: "', $test, '"'))
};

declare function check:err(
  $code as xs:QName,
  $err as xs:string,
  $result as element()
) as xs:string* {
  let $errors := $result/descendant-or-self::*:error
  return if(exists($errors[@code = xs:string($code)])) then ()
  else if(exists($errors)) then (
    concat('Wrong error code [', $code, '] (', $err, '), expected: [',
      string-join($errors//@code, '], ['), ']')
  ) else (
    concat('Expected result, found error: [', $code, '] ', $err)
  )
};

declare function check:any-of(
  $res as item()*,
  $result as element()
) {
  pair:fst(
    fold-left(
      function($p, $n) {
        if(pair:snd($p)) then $p
        else (
          let $r  := check:res($res, $n),
              $ok := empty($r)
          return pair:new(
            if($ok) then () else (pair:fst($p), $r),
            $ok
          )
        )
      },
      pair:new((), false()),
      $result/*
    )
  )
};

declare function check:assert-bool(
  $res as item()*,
  $result as element(),
  $exp as xs:boolean
) {
  if($res instance of xs:boolean and $res eq $exp) then ()
  else concat('Query doesn''t evaluate to ''', $exp, '''')
};

declare function check:assert(
  $res as item()*,
  $result as element()
) as xs:string* {
  try {
    let $assert :=
      util:eval(concat('function($result) { ', xs:string($result), ' }'))
    return if($assert($res)) then ()
      else concat('Assertion ''', $result, ''' failed.')
  } catch *($code, $err) {
    concat('Assertion ''', $result,
      ''' failed with: [', $code, '] ', $err)
  }
};

declare function check:assert-type(
  $res as item()*,
  $result as element()
) as xs:string* {
  try {
    let $type := xs:string($result),
        $test := util:eval(concat(
          'function($x) { $x instance of ', $type, ' }'))
    return if($test($res)) then ()
      else concat('Result doesn''t have type ''', $type, '''.')
  } catch *($code, $err) {
    concat('Type check for ''', $result,
      ''' failed with: [', $code, '] ', $err)
  }
};

declare function check:assert-eq(
  $res as item()*,
  $result as element()
) as xs:string* {
  try {
    let $exp := util:eval($result)
    return if($exp eq $res or $exp ne $exp and $res ne $res) then ()
      else concat('Result doesn''t match expected item ''',
        $exp, '''.')
  } catch *($code, $err) {
    concat('Comparison to ''', $result/text(), ''' failed with: [',
      $code, '] ', $err)
  }
};

declare function check:assert-string-value(
  $res as item()*,
  $result as element()
) as xs:string* {
  try {
    let $str := string-join(for $r in $res return string($r), " "),
        $exp := xs:string($result)
    return if($str eq $exp) then ()
      else concat('Expected ''', $exp, ''', found ''', $str, '''.')
  } catch * ($code, $err) {
    concat('Stringep comparison to ', $result, ' failed with: [',
      $code, '] ', $err)
  }
};

declare function check:assert-deep-eq(
  $res as item()*,
  $result as element()
) {
  try {
    let $exp := util:eval($result)
    return if(deep-equal($res, $exp)) then ()
      else concat('Result is not deep-equal to ''', $result, '''.')
  } catch * ($code, $err) {
    concat('Deep comparison to ''', $result, ''' failed with: [',
      $code, '] ', $err)
  }
};

declare function check:assert-serialization(
  $res as item()*,
  $result as element()
) {
  try {
    let $ser := serialize(
          ?,
          <output:serialization-parameters xmlns:output="http://www.w3.org/2010/xslt-xquery-serialization">
            <output:method>xml</output:method>
            <output:indent>no</output:indent>
          </output:serialization-parameters>
        ),
        $to-str := function($it) {
          if($it instance of node()) then $ser($it)
          else string($it)
        },
        $act := string-join(map($to-str, $res), ' ')
    return if($act eq string($result)) then ()
      else concat('Serialized result ''', $act, ''' not equal to ''', $result, '''.')
  } catch * ($code, $err) {
    concat('Serialized comparison to ''', $result, ''' failed with: [',
      $code, '] ', $err)
  }
};

declare function check:assert-permutation(
  $res as item()*,
  $result as element()
) {
  try {
    let $exp := util:eval($result)
    return if(check:unordered($res, $exp)) then ()
      else concat('Result isn''t a permutation of ''', $result, '''.')
  } catch * ($code, $err) {
    concat('Unordered comparison to ', $result, ' failed with: [',
      $code, '] ', $err)
  }
};

declare function check:unordered(
  $xs as item()*,
  $ys as item()*
) as xs:boolean {
  if(empty($xs)) then empty($ys)
  else
    let $i := check:index-of($ys, head($xs), 1)
    return exists($i)
       and check:unordered(tail($xs), remove($ys, $i))
};

declare function check:index-of(
  $xs as item()*,
  $x  as item(),
  $i  as xs:integer
) as xs:integer? {
  if(empty($xs)) then ()
  else if(deep-equal($x, head($xs))) then $i
  else check:index-of(tail($xs), $x, $i + 1)
};
