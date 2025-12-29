[Skip to main content](#__docusaurus_skipToContent_fallback)

[![Joplin](/images/logo-text-blue.svg)![Joplin](/images/logo-text-blue.svg)](https://joplinapp.org)

[News](/news)[Help](/help/)[Forum](https://discourse.joplinapp.org)[Joplin Cloud](https://joplinapp.org/plans)[♡ Support us](https://joplinapp.org/donate)

English

* [English](/help/api/references/rest_api)
* [Français](/fr/help/api/references/rest_api)
* [Deutsch](/de/help/api/references/rest_api)

* [What is Joplin?](/help/)
* [Installation](/help/install)
* [Using Joplin](/help/apps/)
* [Programmatic API](/help/api/)

  + [Getting started](/help/api/get_started/plugins)
  + [Tutorials](/help/api/tutorials/toc_plugin)
  + [References](/help/api/references/plugin_api_index)

    - [Joplin Plugin API](/help/api/references/plugin_api_index)
    - [Joplin Data API](/help/api/references/rest_api)
    - [Development mode](/help/api/references/development_mode)
    - [Debugging mobile plugins](/help/api/references/mobile_plugin_debugging)
    - [Plugin Loading Rules](/help/api/references/plugin_loading_rules)
    - [Plugin Manifest](/help/api/references/plugin_manifest)
    - [Rendered note metadata](/help/api/references/plugin_rendered_note_metadata)
    - [Plugin theming](/help/api/references/plugin_theming)
* [Development](/help/dev/)
* [About](/help/about/changelog/android)
* [CLA Consent Records](/help/cla/)
* [FAQ](/help/faq)

On this page

# Joplin Data API

[![Donate using PayPal](https://raw.githubusercontent.com/laurent22/joplin/dev/Assets/WebsiteAssets/images/badges/Donate-PayPal-green.svg)](https://www.paypal.com/donate/?hosted_button_id=WQCERTSSLCC7U) [![Sponsor on GitHub](https://raw.githubusercontent.com/laurent22/joplin/dev/Assets/WebsiteAssets/images/badges/GitHub-Badge.svg)](https://github.com/sponsors/laurent22/) [![Become a patron](https://raw.githubusercontent.com/laurent22/joplin/dev/Assets/WebsiteAssets/images/badges/Patreon-Badge.svg)](https://www.patreon.com/joplin) [![Donate using IBAN](https://raw.githubusercontent.com/laurent22/joplin/dev/Assets/WebsiteAssets/images/badges/Donate-IBAN.svg)](https://joplinapp.org/donate/#donations)

This API is available when the clipper server is running. It provides access to the notes, notebooks, tags and other Joplin object via a REST API. Plugins can also access this API even when the clipper server is not running.

In order to use it, you'll first need to find on which port the service is running. To do so, open the Web Clipper Options in Joplin and if the service is running it should tell you on which port. Normally it runs on port **41184**. If you want to find it programmatically, you may follow this kind of algorithm:

```
let port = null;
for (let portToTest = 41184; portToTest <= 41194; portToTest++) {
    const result = pingPort(portToTest); // Call GET /ping
    if (result == 'JoplinClipperServer') {
        port = portToTest; // Found the port
        break;
    }
}
```

## Authorisation[​](#authorisation "Direct link to Authorisation")

To prevent unauthorised applications from accessing the API, the calls must be authenticated. To do so, you must provide a token as a query parameter for each API call. You can get this token from the Joplin desktop application, on the Web Clipper Options screen.

This would be an example of valid cURL call using a token:

```
curl http://localhost:41184/notes?token=ABCD123ABCD123ABCD123ABCD123ABCD123
```

In the documentation below, the token will not be specified every time however you will need to include it.

If needed you may also [request the token programmatically](/help/dev/spec/clipper_auth)

## Using the API[​](#using-the-api "Direct link to Using the API")

All the calls, unless noted otherwise, receives and send **JSON data**. For example to create a new note:

```
curl --data '{ "title": "My note", "body": "Some note in **Markdown**"}' http://localhost:41184/notes
```

In the documentation below, the calls may include special parameters such as :id or :note\_id. You would replace this with the item ID or note ID.

For example, for the endpoint `DELETE /tags/:id/notes/:note_id`, to remove the tag with ID "ABCD1234" from the note with ID "EFGH789", you would run for example:

```
curl -X DELETE http://localhost:41184/tags/ABCD1234/notes/EFGH789
```

The four verbs supported by the API are the following ones:

* **GET**: To retrieve items (notes, notebooks, etc.).
* **POST**: To create new items. In general most item properties are optional. If you omit any, a default value will be used.
* **PUT**: To update an item. Note in a REST API, traditionally PUT is used to completely replace an item, however in this API it will only replace the properties that are provided. For example if you PUT {"title": "my new title"}, only the "title" property will be changed. The other properties will be left untouched (they won't be cleared nor changed).
* **DELETE**: To delete items.

## Filtering data[​](#filtering-data "Direct link to Filtering data")

You can change the fields that will be returned by the API using the `fields=` query parameter, which takes a list of comma separated fields. For example, to get the longitude and latitude of a note, use this:

```
curl http://localhost:41184/notes/ABCD123?fields=longitude,latitude
```

To get the IDs only of all the tags:

```
curl http://localhost:41184/tags?fields=id
```

By default API results will contain the following fields: **id**, **parent\_id**, **title**

## Pagination[​](#pagination "Direct link to Pagination")

All API calls that return multiple results will be paginated and will return the following structure:

| Key | Always present? | Description |
| --- | --- | --- |
| `items` | Yes | The array of items you have requested. |
| `has_more` | Yes | If `true`, there are more items after this page. If `false`, it means you have reached the end of the data set. |

You can specify how the results should be sorted using the `order_by` and `order_dir` query parameters, and which page to retrieve using the `page` parameter (starts at and defaults to 1). You can specify the number of items to be returned using the `limit` parameter (the maximum being 100 items).

The following call for example will initiate a request to fetch all the notes, 10 at a time, and sorted by "updated\_time" ascending:

```
curl http://localhost:41184/notes?order_by=updated_time&order_dir=ASC&limit=10
```

This will return a result like this

```
{ "items": [ /* 10 notes */ ], "has_more": true }
```

Then you will resume fetching the results using this query:

```
curl http://localhost:41184/notes?order_by=updated_time&order_dir=ASC&limit=10&page=2
```

Eventually you will get some results that do not contain an "has\_more" parameter, at which point you will have retrieved all the results

As an example the pseudo-code below could be used to fetch all the notes:

```
async function fetchJson(url) {
    return (await fetch(url)).json();
}

async function fetchAllNotes() {
    let pageNum = 1;
    do {
        const response = await fetchJson((http://localhost:41184/notes?page=' + pageNum++);
        console.info('Printing notes:', response.items);
    } while (response.has_more)
}
```

## Error handling[​](#error-handling "Direct link to Error handling")

In case of an error, an HTTP status code >= 400 will be returned along with a JSON object that provides more info about the error. The JSON object is in the format `{ "error": "description of error" }`.

## About the property types[​](#about-the-property-types "Direct link to About the property types")

* Text is UTF-8.
* All date/time are Unix timestamps in milliseconds.
* Booleans are integer values 0 or 1.

## Testing if the service is available[​](#testing-if-the-service-is-available "Direct link to Testing if the service is available")

Call **GET /ping** to check if the service is available. It should return "JoplinClipperServer" if it works.

## Searching[​](#searching "Direct link to Searching")

Call **GET /search?query=YOUR\_QUERY** to search for notes. This end-point supports the `field` parameter which is recommended to use so that you only get the data that you need. The query syntax is as described in the main documentation: <https://joplinapp.org/help/apps/search>

To retrieve non-notes items, such as notebooks or tags, add a `type` parameter and set it to the required [item type name](#item-type-ids). In that case, full text search will not be used - instead it will be a simple case-insensitive search. You can also use `*` as a wildcard. This is convenient for example to retrieve notebooks or tags by title.

For example, to retrieve the notebook named `recipes`: **GET /search?query=recipes&type=folder**

To retrieve all the tags that start with `project-`: **GET /search?query=project-\*&type=tag**

## Item type IDs[​](#item-type-ids "Direct link to Item type IDs")

Item type IDs might be referred to in certain objects you will retrieve from the API. This is the correspondence between name and ID:

| Name | Value |
| --- | --- |
| note | 1 |
| folder | 2 |
| setting | 3 |
| resource | 4 |
| tag | 5 |
| note\_tag | 6 |
| search | 7 |
| alarm | 8 |
| master\_key | 9 |
| item\_change | 10 |
| note\_resource | 11 |
| resource\_local\_state | 12 |
| revision | 13 |
| migration | 14 |
| smart\_filter | 15 |
| command | 16 |

## Notes[​](#notes "Direct link to Notes")

### Properties[​](#properties "Direct link to Properties")

| Name | Type | Description |
| --- | --- | --- |
| id | text |  |
| parent\_id | text | ID of the notebook that contains this note. Change this ID to move the note to a different notebook. |
| title | text | The note title. |
| body | text | The note body, in Markdown. May also contain HTML. |
| created\_time | int | When the note was created. |
| updated\_time | int | When the note was last updated. |
| is\_conflict | int | Tells whether the note is a conflict or not. |
| latitude | numeric |  |
| longitude | numeric |  |
| altitude | numeric |  |
| author | text |  |
| source\_url | text | The full URL where the note comes from. |
| is\_todo | int | Tells whether this note is a todo or not. |
| todo\_due | int | When the todo is due. An alarm will be triggered on that date. |
| todo\_completed | int | Tells whether todo is completed or not. This is a timestamp in milliseconds. |
| source | text |  |
| source\_application | text |  |
| application\_data | text |  |
| order | numeric |  |
| user\_created\_time | int | When the note was created. It may differ from created\_time as it can be manually set by the user. |
| user\_updated\_time | int | When the note was last updated. It may differ from updated\_time as it can be manually set by the user. |
| encryption\_cipher\_text | text |  |
| encryption\_applied | int |  |
| markup\_language | int |  |
| is\_shared | int | Whether the note is published. |
| share\_id | text | The ID of the Joplin Server/Cloud share containing the note. Empty if not shared. |
| conflict\_original\_id | text |  |
| master\_key\_id | text |  |
| user\_data | text |  |
| deleted\_time | int |  |
| body\_html | text | Note body, in HTML format |
| base\_url | text | If `body_html` is provided and contains relative URLs, provide the `base_url` parameter too so that all the URLs can be converted to absolute ones. The base URL is basically where the HTML was fetched from, minus the query (everything after the '?'). For example if the original page was `https://stackoverflow.com/search?q=%5Bjava%5D+test`, the base URL is `https://stackoverflow.com/search`. |
| image\_data\_url | text | An image to attach to the note, in [Data URL](https://developer.mozilla.org/en-US/docs/Web/HTTP/Basics_of_HTTP/Data_URIs) format. |
| crop\_rect | text | If an image is provided, you can also specify an optional rectangle that will be used to crop the image. In format `{ x: x, y: y, width: width, height: height }` |

### GET /notes[​](#get-notes "Direct link to GET /notes")

Gets all notes

By default, this call will return the all notes **except** the notes in the trash folder and any conflict note. To include these too, you can specify `include_deleted=1` and `include_conflicts=1` as query parameters.

### GET /notes/:id[​](#get-notesid "Direct link to GET /notes/:id")

Gets note with ID :id

### GET /notes/:id/tags[​](#get-notesidtags "Direct link to GET /notes/:id/tags")

Gets all the tags attached to this note.

### GET /notes/:id/resources[​](#get-notesidresources "Direct link to GET /notes/:id/resources")

Gets all the resources attached to this note.

### POST /notes[​](#post-notes "Direct link to POST /notes")

Creates a new note

You can either specify the note body as Markdown by setting the `body` parameter, or in HTML by setting the `body_html`.

Examples:

* Create a note from some Markdown text

```
curl --data '{ "title": "My note", "body": "Some note in **Markdown**"}' http://127.0.0.1:41184/notes
```

* Create a note from some HTML

```
curl --data '{ "title": "My note", "body_html": "Some note in <b>HTML</b>"}' http://127.0.0.1:41184/notes
```

* Create a note and attach an image to it:

```
curl --data '{ "title": "Image test", "body": "Here is Joplin icon:", "image_data_url": "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAIAAABLbSncAAAAGXRFWHRTb2Z0d2FyZQBBZG9iZSBJbWFnZVJlYWR5ccllPAAAANZJREFUeNoAyAA3/wFwtO3K6gUB/vz2+Prw9fj/+/r+/wBZKAAExOgF4/MC9ff+MRH6Ui4E+/0Bqc/zutj6AgT+/Pz7+vv7++nu82c4DlMqCvLs8goA/gL8/fz09fb59vXa6vzZ6vjT5fbn6voD/fwC8vX4UiT9Zi//APHyAP8ACgUBAPv5APz7BPj2+DIaC2o3E+3o6ywaC5fT6gD6/QD9/QEVf9kD+/dcLQgJA/7v8vqfwOf18wA1IAIEVycAyt//v9XvAPv7APz8LhoIAPz9Ri4OAgwARgx4W/6fVeEAAAAASUVORK5CYII="}' http://127.0.0.1:41184/notes
```

#### Creating a note with a specific ID[​](#creating-a-note-with-a-specific-id "Direct link to Creating a note with a specific ID")

When a new note is created, it is automatically assigned a new unique ID so **normally you do not need to set the ID**. However, if for some reason you want to set it, you can supply it as the `id` property. It needs to be a **32 characters long string** in hexadecimal. **Make sure it is unique**, for example by generating it using whatever GUID function is available in your programming language.

```
curl --data '{ "id": "00a87474082744c1a8515da6aa5792d2", "title": "My note with custom ID"}' http://127.0.0.1:41184/notes
```

### PUT /notes/:id[​](#put-notesid "Direct link to PUT /notes/:id")

Sets the properties of the note with ID :id

### DELETE /notes/:id[​](#delete-notesid "Direct link to DELETE /notes/:id")

Deletes the note with ID :id

By default, the note will be moved **to the trash**. To permanently delete it, add the query parameter `permanent=1`

## Folders[​](#folders "Direct link to Folders")

This is actually a notebook. Internally notebooks are called "folders".

### Properties[​](#properties-1 "Direct link to Properties")

| Name | Type | Description |
| --- | --- | --- |
| id | text |  |
| title | text | The folder title. |
| created\_time | int | When the folder was created. |
| updated\_time | int | When the folder was last updated. |
| user\_created\_time | int | When the folder was created. It may differ from created\_time as it can be manually set by the user. |
| user\_updated\_time | int | When the folder was last updated. It may differ from updated\_time as it can be manually set by the user. |
| encryption\_cipher\_text | text |  |
| encryption\_applied | int |  |
| parent\_id | text |  |
| is\_shared | int |  |
| share\_id | text | The ID of the Joplin Server/Cloud share containing the folder. Empty if not shared. |
| master\_key\_id | text |  |
| icon | text |  |
| user\_data | text |  |
| deleted\_time | int |  |

### GET /folders[​](#get-folders "Direct link to GET /folders")

Gets all folders

The folders are returned as a tree. The sub-notebooks of a notebook, if any, are under the `children` key.

### GET /folders/:id[​](#get-foldersid "Direct link to GET /folders/:id")

Gets folder with ID :id

### GET /folders/:id/notes[​](#get-foldersidnotes "Direct link to GET /folders/:id/notes")

Gets all the notes inside this folder.

### POST /folders[​](#post-folders "Direct link to POST /folders")

Creates a new folder

### PUT /folders/:id[​](#put-foldersid "Direct link to PUT /folders/:id")

Sets the properties of the folder with ID :id

### DELETE /folders/:id[​](#delete-foldersid "Direct link to DELETE /folders/:id")

Deletes the folder with ID :id

By default, the folder will be moved **to the trash**. To permanently delete it, add the query parameter `permanent=1`

## Resources[​](#resources "Direct link to Resources")

### Properties[​](#properties-2 "Direct link to Properties")

| Name | Type | Description |
| --- | --- | --- |
| id | text |  |
| title | text | The resource title. |
| mime | text |  |
| filename | text |  |
| created\_time | int | When the resource was created. |
| updated\_time | int | When the resource was last updated. |
| user\_created\_time | int | When the resource was created. It may differ from created\_time as it can be manually set by the user. |
| user\_updated\_time | int | When the resource was last updated. It may differ from updated\_time as it can be manually set by the user. |
| file\_extension | text |  |
| encryption\_cipher\_text | text |  |
| encryption\_applied | int |  |
| encryption\_blob\_encrypted | int |  |
| size | int |  |
| is\_shared | int |  |
| share\_id | text | The ID of the Joplin Server/Cloud share containing the resource. Empty if not shared. |
| master\_key\_id | text |  |
| user\_data | text |  |
| blob\_updated\_time | int |  |
| ocr\_text | text |  |
| ocr\_details | text |  |
| ocr\_status | int |  |
| ocr\_error | text |  |
| ocr\_driver\_id | int |  |

### GET /resources[​](#get-resources "Direct link to GET /resources")

Gets all resources

### GET /resources/:id[​](#get-resourcesid "Direct link to GET /resources/:id")

Gets resource with ID :id

### GET /resources/:id/file[​](#get-resourcesidfile "Direct link to GET /resources/:id/file")

Gets the actual file associated with this resource.

### GET /resources/:id/notes[​](#get-resourcesidnotes "Direct link to GET /resources/:id/notes")

Gets the notes (IDs) associated with a resource.

### POST /resources[​](#post-resources "Direct link to POST /resources")

Creates a new resource

Creating a new resource is special because you also need to upload the file. Unlike other API calls, this one must have the "multipart/form-data" Content-Type. The file data must be passed to the "data" form field, and the other properties to the "props" form field. An example of a valid call with cURL would be:

```
curl -F 'data=@/path/to/file.jpg' -F 'props={"title":"my resource title"}' http://localhost:41184/resources
```

To **update** the resource content, you can make a PUT request with the same arguments:

```
curl -X PUT -F 'data=@/path/to/file.jpg' -F 'props={"title":"my modified title"}' http://localhost:41184/resources/8fe1417d7b184324bf6b0122b76c4696
```

The "data" field is required, while the "props" one is not. If not specified, default values will be used.

Or if you only need to update the resource properties (title, etc.), without changing the content, you can make a regular PUT request:

```
curl -X PUT --data '{"title": "My new title"}' http://localhost:41184/resources/8fe1417d7b184324bf6b0122b76c4696
```

**From a plugin** the syntax to create a resource is also a bit special:

```
    await joplin.data.post(
        ["resources"],
        null,
        { title: "test.jpg" }, // Resource metadata
        [
            {
                path: "/path/to/test.jpg", // Actual file
            },
        ]
    );
```

### PUT /resources/:id[​](#put-resourcesid "Direct link to PUT /resources/:id")

Sets the properties of the resource with ID :id

You may also update the file data by specifying a file (See `POST /resources` example).

### DELETE /resources/:id[​](#delete-resourcesid "Direct link to DELETE /resources/:id")

Deletes the resource with ID :id

## Tags[​](#tags "Direct link to Tags")

### Properties[​](#properties-3 "Direct link to Properties")

| Name | Type | Description |
| --- | --- | --- |
| id | text |  |
| title | text | The tag title. |
| created\_time | int | When the tag was created. |
| updated\_time | int | When the tag was last updated. |
| user\_created\_time | int | When the tag was created. It may differ from created\_time as it can be manually set by the user. |
| user\_updated\_time | int | When the tag was last updated. It may differ from updated\_time as it can be manually set by the user. |
| encryption\_cipher\_text | text |  |
| encryption\_applied | int |  |
| is\_shared | int |  |
| parent\_id | text |  |
| user\_data | text |  |

### GET /tags[​](#get-tags "Direct link to GET /tags")

Gets all tags

### GET /tags/:id[​](#get-tagsid "Direct link to GET /tags/:id")

Gets tag with ID :id

### GET /tags/:id/notes[​](#get-tagsidnotes "Direct link to GET /tags/:id/notes")

Gets all the notes with this tag.

### POST /tags[​](#post-tags "Direct link to POST /tags")

Creates a new tag

### POST /tags/:id/notes[​](#post-tagsidnotes "Direct link to POST /tags/:id/notes")

Post a note to this endpoint to add the tag to the note. The note data must at least contain an ID property (all other properties will be ignored).

### PUT /tags/:id[​](#put-tagsid "Direct link to PUT /tags/:id")

Sets the properties of the tag with ID :id

### DELETE /tags/:id[​](#delete-tagsid "Direct link to DELETE /tags/:id")

Deletes the tag with ID :id

### DELETE /tags/:id/notes/:note\_id[​](#delete-tagsidnotesnote_id "Direct link to DELETE /tags/:id/notes/:note_id")

Remove the tag from the note.

## Revisions[​](#revisions "Direct link to Revisions")

### Properties[​](#properties-4 "Direct link to Properties")

| Name | Type | Description |
| --- | --- | --- |
| id | text |  |
| parent\_id | text |  |
| item\_type | int |  |
| item\_id | text |  |
| item\_updated\_time | int |  |
| title\_diff | text |  |
| body\_diff | text |  |
| metadata\_diff | text |  |
| encryption\_cipher\_text | text |  |
| encryption\_applied | int |  |
| updated\_time | int |  |
| created\_time | int |  |

### GET /revisions[​](#get-revisions "Direct link to GET /revisions")

Gets all revisions

### GET /revisions/:id[​](#get-revisionsid "Direct link to GET /revisions/:id")

Gets revision with ID :id

### POST /revisions[​](#post-revisions "Direct link to POST /revisions")

Creates a new revision

### PUT /revisions/:id[​](#put-revisionsid "Direct link to PUT /revisions/:id")

Sets the properties of the revision with ID :id

### DELETE /revisions/:id[​](#delete-revisionsid "Direct link to DELETE /revisions/:id")

Deletes the revision with ID :id

## Events[​](#events "Direct link to Events")

This end point can be used to retrieve the latest note changes. Currently only note changes are tracked.

### Properties[​](#properties-5 "Direct link to Properties")

| Name | Type | Description |
| --- | --- | --- |
| id | int |  |
| item\_type | int | The item type (see table above for the list of item types) |
| item\_id | text | The item ID |
| type | int | The type of change - either 1 (created), 2 (updated) or 3 (deleted) |
| created\_time | int | When the event was generated |
| source | int | Unused |
| before\_change\_item | text | Unused |

### GET /events[​](#get-events "Direct link to GET /events")

Returns a paginated list of recent events. A `cursor` property should be provided, which tells from what point in time the events should be returned. The API will return a `cursor` property, to tell from where to resume retrieving events, as well as an `has_more` (tells if more changes can be retrieved) and `items` property, which will contain the list of events. Events are kept for up to 90 days.

If no `cursor` property is provided, the API will respond with the latest change ID. That can be used to retrieve future events later on.

The results are paginated so you may need multiple calls to retrieve all the events. Use the `has_more` property to know if more can be retrieved.

### GET /events/:id[​](#get-eventsid "Direct link to GET /events/:id")

Returns the event with the given ID.

[Edit this page](https://github.com/laurent22/joplin/tree/dev/readme/api/references/rest_api.md)

[Previous

Joplin Plugin API](/help/api/references/plugin_api_index)[Next

Development mode](/help/api/references/development_mode)

* [Authorisation](#authorisation)
* [Using the API](#using-the-api)
* [Filtering data](#filtering-data)
* [Pagination](#pagination)
* [Error handling](#error-handling)
* [About the property types](#about-the-property-types)
* [Testing if the service is available](#testing-if-the-service-is-available)
* [Searching](#searching)
* [Item type IDs](#item-type-ids)
* [Notes](#notes)
  + [Properties](#properties)
  + [GET /notes](#get-notes)
  + [GET /notes/:id](#get-notesid)
  + [GET /notes/:id/tags](#get-notesidtags)
  + [GET /notes/:id/resources](#get-notesidresources)
  + [POST /notes](#post-notes)
  + [PUT /notes/:id](#put-notesid)
  + [DELETE /notes/:id](#delete-notesid)
* [Folders](#folders)
  + [Properties](#properties-1)
  + [GET /folders](#get-folders)
  + [GET /folders/:id](#get-foldersid)
  + [GET /folders/:id/notes](#get-foldersidnotes)
  + [POST /folders](#post-folders)
  + [PUT /folders/:id](#put-foldersid)
  + [DELETE /folders/:id](#delete-foldersid)
* [Resources](#resources)
  + [Properties](#properties-2)
  + [GET /resources](#get-resources)
  + [GET /resources/:id](#get-resourcesid)
  + [GET /resources/:id/file](#get-resourcesidfile)
  + [GET /resources/:id/notes](#get-resourcesidnotes)
  + [POST /resources](#post-resources)
  + [PUT /resources/:id](#put-resourcesid)
  + [DELETE /resources/:id](#delete-resourcesid)
* [Tags](#tags)
  + [Properties](#properties-3)
  + [GET /tags](#get-tags)
  + [GET /tags/:id](#get-tagsid)
  + [GET /tags/:id/notes](#get-tagsidnotes)
  + [POST /tags](#post-tags)
  + [POST /tags/:id/notes](#post-tagsidnotes)
  + [PUT /tags/:id](#put-tagsid)
  + [DELETE /tags/:id](#delete-tagsid)
  + [DELETE /tags/:id/notes/:note\_id](#delete-tagsidnotesnote_id)
* [Revisions](#revisions)
  + [Properties](#properties-4)
  + [GET /revisions](#get-revisions)
  + [GET /revisions/:id](#get-revisionsid)
  + [POST /revisions](#post-revisions)
  + [PUT /revisions/:id](#put-revisionsid)
  + [DELETE /revisions/:id](#delete-revisionsid)
* [Events](#events)
  + [Properties](#properties-5)
  + [GET /events](#get-events)
  + [GET /events/:id](#get-eventsid)

Community

* [Bluesky](https://bsky.app/profile/joplinapp.bsky.social)
* [Patreon](https://www.patreon.com/joplin)
* [YouTube](https://www.youtube.com/%40joplinapp)
* [LinkedIn](https://www.linkedin.com/company/joplin)
* [Discord](https://discord.gg/VSj7AFHvpq)
* [Mastodon](https://mastodon.social/%40joplinapp)
* [Lemmy](https://sopuli.xyz/c/joplinapp)
* [GitHub](https://github.com/laurent22/joplin/)

Legal

* [Privacy Policy](https://joplinapp.org/privacy)

Copyright © 2016-2025 Laurent Cozic
