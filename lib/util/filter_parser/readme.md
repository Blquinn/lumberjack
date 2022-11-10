# Filter query language spec

The filter language allows you to filter logs based
on [json path expressions](https://www.ietf.org/archive/id/draft-goessner-dispatch-jsonpath-00.html).

Each expression has on one side, a json path, which extracts the value the expression
is going to be evaluated against; on the other side is the value to compare.

For example given the following json object

```json
{
  "foo": {
    "bar": "baz"
  }
}
```

The expression:

```
$.foo.bar == 'baz'
```

Would return true.

The expression:

```
$.foo.bar == 3
```

or

```
$.foo.sldkj == 3
```

Would return false.

### Boolean operators

You can combine multiple expressions with boolean operators.

For example:

```
$.foo == 'bar' and $.bar == 3
```

### Nested filters

You can nest expressions inside parentheses.

For example:

```
$.foo == 'bar' and ($.bar == 3 or $.bin == 4)
```

### Comparators

You can compare values with the following comparator operators

| Operator | Definition                                                |
|----------|-----------------------------------------------------------|
| `==`     | Is equal                                                  |
| `<`      | Less than                                                 |
| `>`      | Greater than                                              |
| `<=`     | LTE                                                       |
| `>=`     | GTE                                                       |
| `in`     | (strings only) is substring contained by the other string |

### Shorthand json path selectors

You can shorten json path selectors to just the field name for brevity

```
$.foo == 3
```

Can be expressed as

```
foo == 3
```
