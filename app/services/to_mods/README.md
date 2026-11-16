# ToMods: cocina → MODS

`ToMods` writes MODS XML from cocina JSON. It doesn't depend on the `cocina-models` structs, so it
works with any cocina JSON hash. For example, it can build MODS "just in time" from a stored public
cocina document rather than only at deposit.

```ruby
ToMods::Description.transform(cocina['description'], cocina['externalIdentifier'],
                              identification: cocina['identification'])
```

## How cocina is read

Values are read in this order of preference:

1. **CocinaDisplay objects** (from the `cocina_display` gem) wherever they model what MODS needs.
2. **Named JSONPath queries** in [`ToMods::Query`](query.rb) for everything else. Each property has
   one named accessor (`Query.authority`, `Query.value_at`, `Query.notes_of_type`, …), so a
   schema change only needs to be handled in one place.
3. **Hash operations** only where the cocina structure itself is the data: comparing titles to
   names for nameTitleGroups, and passing a filtered copy of a related resource to the writer.

The description is wrapped in a `CocinaDisplay::CocinaRecord`, and each related resource in a
`CocinaDisplay::RelatedResource`. `ModsWriter` writes either one, which is how relatedItems
recurse. The individual writers accept cocina hashes and wrap them in CocinaDisplay objects as
needed.

## Where CocinaDisplay is used

| Writer | CocinaDisplay usage |
| --- | --- |
| `ModsWriter` / `Description` | `CocinaRecord` and `RelatedResource` records, queried with `#path` |
| `Title` | `Titles::Title#parallel_values`, `ParallelValue#role` (translated/transliterated), `#primary?`, `#own_type` |
| `NameWriter` | `Contributors::Contributor#names`, `#roles`, `#affiliations` (`Affiliation#display_name`), `#identifiers`, `#primary?` |
| `RoleWriter` | `Contributors::Role#code` |
| `Language`, `AdminMetadata` | `Languages::Language#code` and `#script` (understands both `script` and `valueScript`) |
| `Query.lang` / `Query.script` | `Languages::Language` for every `valueLanguage` |
| `Note` | `Notes::Note#parallel_values` |
| `Event` | `Events::Event#type`, `#contributors`, `#locations`, `#notes` |
| `Form` | `Forms::ResourceType#mods?` and `#stanford_self_deposit?` |
| `Access` | `Description::Url#link_text`, `Description::Access#type`, `Description::AccessContact#contact_email?` |
| `Subject` | `Subjects::Subject#parallel_values` and `ParallelValue#display?` |

## Where CocinaDisplay isn't sufficient

CocinaDisplay is built for display and indexing. It returns formatted strings and normalized
values, and it doesn't expose the raw attributes that become MODS attributes. These are the gaps
that `ToMods::Query` covers:

- **Raw attributes.** No CocinaDisplay class exposes `uri`, `source.code`/`source.uri` (authority),
  `displayLabel` (on most classes), `valueAt` (xlink:href), `status` (except `#primary?`),
  `standard`, `encoding`, `qualifier`, `appliesTo` or anchor identifiers.
- **Values as recorded.** Several `#to_s`/`#value` methods change the cocina value, so MODS can't
  use them:
  - `Role#to_s` decodes MARC relator codes.
  - `Language#to_s` decodes language codes.
  - `LocationValue#to_s` decodes MARC country codes.
  - `Genre#to_s` capitalizes, and `ResourceType#to_s` downcases.
  - `Identifier#value` prefers the uri, and `Identifier#type` normalizes DOI/ORCID.
- **Record-level collections combine sources.**
  - `CocinaRecord#contributors` includes event contributors, which MODS writes as `publisher`.
  - `#all_forms` and `#all_subjects` include the `geographic` forms and subjects, which go to the
    geo extension.
  - `#all_identifiers` adds the DOI from `identification`, which `PublicDescMetadataService`
    handles separately.
- **Dates.** `Events::Event#dates` and `Dates::Date` drop dates they can't parse and fold
  structured values into ranges. MODS must reproduce every date, with its encoding, qualifier,
  point and calendar.
- **Structure.** MODS keeps cocina structure that display flattens:
  - structuredValue/groupedValue parts become separate `titleInfo`, `namePart`, `part`/`detail`
    and `physicalDescription` children. `Utils.flatten_nested_values` and
    `NoteValue#values_by_type` lose this grouping.
  - `ParallelValue#type` inherits the type from the main value or the parent, but MODS needs each
    node's own type.
  - `Parallel#parallel_values` returns the node itself when there is no `parallelValue`. Writers
    check `Query.parallel?` first.
- **Different vocabularies.**
  - `NoteValue#abstract?` treats a different set of display labels as abstracts than MODS does (it
    doesn't include "Content advice", "Subject" or "Review").
  - `Note#part?` looks at the main parallel value's type instead of the note's own type.
- **No MODS-only concepts.** CocinaDisplay has nothing for nameTitleGroups, altRepGroups,
  cartographics, physicalDescription grouping, part notes, admin metadata (except the creation
  event), or the geo extension, whose coordinates must be written as recorded rather than parsed
  by `Geospatial::Coordinates`.

If CocinaDisplay gains accessors for any of these, the matching `Query` methods can be replaced.
