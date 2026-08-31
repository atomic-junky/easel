class_name CosmosFetcher extends EaselFetcherPlugin

const USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:141.0) Gecko/20100101 Firefox/141.0"
const QUERIES: Dictionary = {
	"GetClusterBySlug": "query GetClusterBySlug($input: ClusterGetInput!, $userId: UserId!, $ownerOrgId: OrganizationId, $isAdmin: Boolean! = false, $isSubcluster: Boolean! = false, $subClusterSlug: String, $isLoggedIn: Boolean!, $includeFollowersCount: Boolean = true) {\n  cluster(input: $input) {\n    ...ClusterDetails\n    ownerOrgIsPinnedToUserProfile: isPinnedToUserProfile(\n      userId: $userId\n      ownerOrgId: $ownerOrgId\n    ) @include(if: $isLoggedIn)\n    ...ClusterAdminDetails @include(if: $isAdmin)\n    subCluster(slug: $subClusterSlug) @include(if: $isSubcluster) {\n      ...ClusterDetails\n      __typename\n    }\n    subClusters {\n      items {\n        __typename\n        id\n        ...SubclusterPill\n      }\n      meta {\n        count\n        __typename\n      }\n      __typename\n    }\n    __typename\n  }\n  clusterConnections(clusterInput: $input) {\n    meta {\n      count\n      __typename\n    }\n    __typename\n  }\n}\n\nfragment ClusterDetails on Cluster {\n  ...ClusterBasic\n  owner {\n    ...UserPublicProfile\n    __typename\n  }\n  collaborators {\n    items {\n      userId\n      isOwner\n      status\n      collaboratorPublicProfile {\n        ...UserPublicProfile\n        __typename\n      }\n      __typename\n    }\n    __typename\n  }\n  isFollowed(userId: $userId) @include(if: $isLoggedIn)\n  isCollaborator(userId: $userId) @include(if: $isLoggedIn)\n  followersCount @include(if: $includeFollowersCount)\n  numberOfElements\n  __typename\n}\n\nfragment ClusterBasic on Cluster {\n  id\n  name\n  isPublicElementsCluster\n  description\n  slug\n  isPrivate\n  ownerId\n  owner {\n    ...UserPublicProfile\n    isFollowed(followerId: $userId) @include(if: $isLoggedIn)\n    __typename\n  }\n  coverImageElementId\n  coverImageUrl\n  isFollowed(userId: $userId) @include(if: $isLoggedIn)\n  isFeatured\n  parentClusterId\n  isPinnedToUserProfile(userId: $userId) @include(if: $isLoggedIn)\n  numberOfElements\n  cover {\n    notSafeForWorkStatus\n    url\n    blurHash\n    width\n    height\n    aiGenerated\n    ... on AnimatedImage {\n      video {\n        url\n        thumbnailUrl\n        __typename\n      }\n      __typename\n    }\n    __typename\n  }\n  collaborators {\n    items {\n      ...ClusterCollaborator\n      isOwner\n      status\n      __typename\n    }\n    __typename\n  }\n  __typename\n}\n\nfragment ClusterCollaborator on Collaborator {\n  userId\n  collaboratorPublicProfile {\n    ...UserPublicProfile\n    __typename\n  }\n  __typename\n}\n\nfragment UserPublicProfile on UserPublicProfile {\n  id\n  fullName\n  username\n  avatarUrl\n  isPremium\n  isVerifiedProfile\n  publicElementsCluster {\n    id\n    numberOfElements\n    __typename\n  }\n  verifiedProfile {\n    ...VerifiedProfile\n    __typename\n  }\n  __typename\n}\n\nfragment VerifiedProfile on VerifiedProfile {\n  __typename\n  id\n  slug\n  isPublic\n  status\n  name\n  avatarUrl\n  avatarThumbnailCropParameters {\n    width\n    height\n    __typename\n  }\n  coverImage {\n    url\n    hash\n    thumbnailUrl\n    __typename\n  }\n  brand {\n    __typename\n    id\n    slug\n  }\n}\n\nfragment ClusterAdminDetails on Cluster {\n  id\n  isBanned\n  type\n  categories {\n    id\n    name\n    __typename\n  }\n  isAesthetic\n  __typename\n}\n\nfragment SubclusterPill on Cluster {\n  id\n  name\n  slug\n  numberOfElements\n  coverImageUrl\n  cover {\n    url\n    width\n    height\n    blurHash\n    notSafeForWorkStatus\n    aiGenerated\n    __typename\n  }\n  owner {\n    id\n    username\n    __typename\n  }\n  isPrivate\n  collaboratorsCount\n  collaborators {\n    items {\n      ...ClusterCollaborator\n      isOwner\n      status\n      __typename\n    }\n    __typename\n  }\n  __typename\n}",
	"GetClusterElements": "query GetClusterElements($clusterId:ClusterId$pageCursor:String$userId:UserId$pageSize:Int$isLoggedIn:Boolean!$showCollaborator:Boolean!){clusterConnections(clusterId:$clusterId meta:{pageSize:$pageSize pageCursor:$pageCursor}){items{element{...ElementTile userContext(userId:$userId)@include(if:$isLoggedIn){...ElementUserContext}connection(cluster:{id:$clusterId})@include(if:$showCollaborator){collaborator{id username avatarUrl isPremium}}}}meta{nextPageCursor count}}}fragment ElementTile on ElementTile{__typename id processingState contentAccessibility createdAt isFeatured isReadyToShow hasIllegalReports ownerId owner{username isVerifiedProfile verifiedProfile{slug brand{__typename id slug}avatarUrl avatarThumbnailCropParameters{width height}}}shareUrl originalClusterId generatedCaption{text __typename}source{...ElementSource}product{...Product}...on MediaElementTile{hasMoreMedia multipleMedia{...ElementMedia}media{...ElementMedia}secondaryMedia{...ElementMedia}}...on ProductElementTile{media{...ElementMedia}productPrice:price{value currency}productBrand:brand productTitle:name productDescription:description}...on WebsiteElementTile{media{...ElementMedia}websiteTitle:title websiteDescription:description}...on TextElementTile{text}}fragment ElementMedia on Media{mediaId url width height notSafeForWorkStatus aiGenerated __typename ...on StaticImage{blurHash}...on AnimatedImage{blurHash video{url thumbnailUrl}}...on Video{thumbnail{hash url}duration isStored mux{playbackUrl mp4Url(quality:LOW)}width height}...on Media{__typename}}fragment ElementSource on ElementSource{url isEditable isPublicDomain author{username fullName profileUrl avatarUrl}}fragment Product on Product{__typename id name description brand{id name}listPrice{value currency}salePrice{value currency}availability delistedAt categories{slug}offers{url domain}}fragment ElementUserContext on ElementUserContext{isDisliked isPublicElement connections{meta{count}}}"
}
const PAGE_SIZE: int = 100


static func plugin_id() -> StringName:
	return &"cosmos"


static func display_name() -> String:
	return "Cosmos"


static func can_handle(url: String) -> bool:
	return host_of(url) == "cosmos.so"


static func icon_path() -> String:
	return "res://assets/icons/image.svg"


func on_fetch(url: String, _params: Dictionary) -> Array[PackFetchResult]:
	var segments: PackedStringArray = get_url_segments(url)
	if segments[0] != "cosmos.so" or segments.size() < 3:
		return [PackFetchResult.failure("Invalid url.")]

	var owner_username: String = segments[1]
	var slug: String = segments[2]

	var cluster_data: ClusterData = await get_cluster_by_slug(owner_username, slug)
	if cluster_data == null:
		printerr("ClusterData is null.")
		return [PackFetchResult.failure("Failed to find cluster.")]

	var elements: Array[ElementData] = []
	elements.append_array(await get_cluster_elements(cluster_data.id, cluster_data.number_of_elements))

	report("Found %s elements." % [elements.size()])

	var images: Array = []
	for element: ElementData in elements:
		var image: Dictionary = element.as_image()
		if not image.is_empty():
			images.append(image)

	if images.is_empty():
		return [PackFetchResult.failure("No usable image in this cluster.")]

	return [PackFetchResult.success(cluster_data.name, url, images)]


func build_body(operation_name: String, query: String, variables: Dictionary) -> String:
	return JSON.stringify({
		"operationName": operation_name,
		"query": query,
		"variables": variables
	}, "", false, true)


func get_api_url(operation: String) -> String:
	return "https://api.cosmos.so/graphql?q=%s" % operation


func get_request_headers() -> PackedStringArray:
	return [
		"User-Agent: %s" % USER_AGENT,
		"Content-Type: application/json",
		"Accept: application/json; charset=utf-8"
	] as PackedStringArray


func get_cluster_by_slug(owner_username: String, slug: String) -> ClusterData:
	var operation: String = "GetClusterBySlug"
	var url: String = get_api_url(operation)
	var body: String = build_body(
		operation,
		QUERIES.get(operation),
		{
			"includeFollowersCount": false,
			"input": {
				"ownerUsername": owner_username,
				"slug": slug
			},
			"isAdmin": false,
			"isLoggedIn": false,
			"isSubcluster": false,
			"userId": 0
		}
	)
	var result: HTTPResult = await async_request(url, get_request_headers(), HTTPClient.METHOD_POST, body)
	if not result.status_ok():
		progress_callback.call("Failed to find cluster.")
		printerr("Can't find cluster from slug.")
		return null
	
	var data: Dictionary = result.body_as_json()
	return ClusterData.from_body(data)


func get_cluster_elements(cluster_id: int, count: int) -> Array[ElementData]:
	var page_number: int = ceili(float(count) / PAGE_SIZE)
	
	var elements: Array[ElementData] = []
	var page_cursor: Variant = null
	for i: int in range(page_number):
		page_cursor = await get_page_elements(elements, cluster_id, page_cursor)
		progress_callback.call("Found %s/%s elements." % [elements.size(), count])
		
		if page_cursor == null:
			break
	
	return elements


func get_page_elements(elements: Array[ElementData], cluster_id: int, page_cursor: Variant = null) -> Variant:
	var operation: String = "GetClusterElements"
	var url: String = get_api_url(operation)
	var body: String = build_body(
		operation,
		QUERIES.get(operation),
		{
			"clusterId": cluster_id,
			"pageCursor": page_cursor,
			"userId": 0,
			"pageSize": PAGE_SIZE,
			"isLoggedIn": false,
			"showCollaborator": false
		}
	)
	var result: HTTPResult = await async_request(url, get_request_headers(), HTTPClient.METHOD_POST, body)
	if not result.status_ok():
		progress_callback.call("Failed to find cluster.")
		printerr("Can't find cluster from slug.")
		return []
	
	var data: Dictionary = result.body_as_json()
	var elem_data: Dictionary = data.get("data", {})
	var connections: Dictionary = elem_data.get("clusterConnections", {})
	var raw_elements: Array = connections.get("items", [])
	
	var meta: Dictionary = connections.get("meta", {})
	var next_page_cursor: Variant = meta.get("nextPageCursor")
	
	for element: Dictionary in raw_elements:
		elements.append(ElementData.from_dict(element))
		
	return next_page_cursor


class ClusterData:
	var id: int
	var name: String
	var description: String
	var slug: String
	var owner_id: int
	var number_of_elements: int = 0
	var sub_clusters: Array = []
	
	var _raw: Dictionary
	
	static func from_body(body: Dictionary) -> ClusterData:
		var result: ClusterData = ClusterData.new()
		result._raw = body
		
		var data: Dictionary = body.get("data", {})
		var cluster: Dictionary = data.get("cluster", {})
		
		result.id = cluster.get("id")
		result.name = cluster.get("name")
		result.description = cluster.get("description") if cluster.get("description") != null else ""
		result.slug = cluster.get("slug")
		result.owner_id = cluster.get("ownerId")
		result.number_of_elements = cluster.get("numberOfElements")
		
		result.sub_clusters = cluster.get("subClusters", {}).get("items", [])
		
		return result


class ElementData:
	var id: int
	var media_url: String
	var media_type_name: String
	var source: String = ""
	var share_url: String
	
	var _raw: Dictionary
	
	static func from_dict(dict: Dictionary) -> ElementData:
		var result: ElementData = ElementData.new()
		result._raw = dict
		
		var data: Dictionary = dict.get("element", {})
		var media: Dictionary = data.get("media", {})
		result.id = data.get("id")
		result.media_url = media.get("url")
		result.media_type_name = media.get("__typename")
		result.share_url = data.get("shareUrl")
		if data.get("source") != null:
			result.source = data.get("source", {}).get("url", "")

		return result

	## Pack image entry, or {} when the media cannot be loaded by the app.
	func as_image() -> Dictionary:
		if media_url.is_empty():
			return {}
		if not media_type_name in ["StaticImage"]:
			return {}
		return {"path": media_url, "name": source if not source.is_empty() else str(id)}
