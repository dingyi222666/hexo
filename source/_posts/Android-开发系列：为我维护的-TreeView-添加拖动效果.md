---
title: Android 开发系列：为我维护的 TreeView 添加拖放效果
date: 2023-08-23 02:08:04
categories:
  - 学习
tags:
  - Android
  - Kotlin
description: 其实是给 RecyclerView 添加的效果...
url_title: android_develop_series_add_drag_effect_to_treeview
---

## 前言

大半夜维护 [ChatHub](https://github.com/ChatHubLab/chathub)，忽然看到我之前写的 [TreeView](https://github.com/dingyi222666/TreeView) 有人提了个 [issue](https://github.com/dingyi222666/TreeView/issues/8)，说想要一个拖放的效果。

我一想，我们这个 TreeView 其实就是在 RecyclerView 上的实现，那么这个效果其实就是给 RecyclerView 添加的效果，那么就可以直接用 [ItemTouchHelper](https://developer.android.com/reference/android/support/v7/widget/helper/ItemTouchHelper) 来实现。

下面我来实际的记录一下我是怎么在我这个项目里实现的。

## 实现

### 1. 拖动效果

拖动效果的实现其实不是很难，只需要新建一个类继承 `ItemTouchHelper.Callback`，实现相关方法，然后绑定到 RecyclerView 上就可以了。

```kotlin
private inner class ItemTouchHelperCallback : ItemTouchHelper.Callback() {

    private var tempMoveNodes: Pair<TreeNode<T>, TreeNode<T>>? = null
    private var originNode: TreeNode<T>? = null

    override fun getMovementFlags(
         recyclerView: RecyclerView,
         viewHolder: RecyclerView.ViewHolder
    ): Int {
         // 只允许上下拖动
         return makeMovementFlags(
            if (supportDragging) ItemTouchHelper.UP or ItemTouchHelper.DOWN else 0,
            0
        )
    }

    override fun onMove(
         recyclerView: RecyclerView,
        viewHolder: RecyclerView.ViewHolder,
        target: RecyclerView.ViewHolder
    ): Boolean {
        val srcNode = this@TreeView._adapter.getItem(viewHolder.adapterPosition)
            // look up?
        var targetNode = this@TreeView._adapter.getItem(max(0, target.adapterPosition - 1))

        if (targetNode.depth == 0) {
            targetNode = tree.getParentNode(targetNode) ?: targetNode
        }

        if (srcNode.path == targetNode.path) {
            targetNode = this@TreeView._adapter.getItem(target.adapterPosition)
        }

        if (originNode == null) {
            originNode = srcNode
        }

        val canMove = binder.onMoveView(viewHolder, srcNode, target, targetNode)

        tempMoveNodes = Pair(srcNode, targetNode)

        if (!canMove) {
             return false
        }

        return this@TreeView._adapter.onMoveHolder(viewHolder, target)
    }

    override fun isItemViewSwipeEnabled(): Boolean = false

    override fun isLongPressDragEnabled(): Boolean {
        return supportDragging
    }

    override fun onSelectedChanged(viewHolder: RecyclerView.ViewHolder?, actionState: Int) {
        if (viewHolder == null) {
            return
        }
        val srcNode = this@TreeView._adapter.getItem(viewHolder.adapterPosition)
        when (actionState) {
            ItemTouchHelper.ACTION_STATE_DRAG -> {
                binder.onMoveView(viewHolder, srcNode)
            }

            ItemTouchHelper.ACTION_STATE_IDLE -> {
                binder.onMovedView(srcNode, null, viewHolder)
            }
        }
    }

    override fun onSwiped(viewHolder: RecyclerView.ViewHolder, direction: Int) {
        // Do nothing
    }

    override fun clearView(recyclerView: RecyclerView, viewHolder: RecyclerView.ViewHolder) {
        super.clearView(recyclerView, viewHolder)
        val (left, right) = tempMoveNodes ?: return

        this@TreeView.coroutineScope.launch(Dispatchers.Main) {
            this@TreeView.binder.onMovedView(
                left,
                right,
                viewHolder
            )
            left.depth = originNode?.depth ?: left.depth
            this@TreeView.tree.moveNode(left, right)
            this@TreeView.refresh(false)
        }

        tempMoveNodes = null
        originNode = null
    }
}
```

上面有几点是需要注意的：

1. 上面的 targetNode 我是向上取的。实际上用户在拖动的时候，拖动时候确实是在当前节点的上方，留给了一个位置。也就是说，用户在拖动时，实际上是在当前节点的上方的位置，而不是当前节点的位置。所以这里我是向上取的，然后在 onMoveHolder 里面做了处理。

2. 在 `clearView` 里我重置了原始节点的深度，这样也方便后续判断。

这是绑定的实现

```kotlin
this._itemTouchHelperCallback = ItemTouchHelperCallback()

val itemTouchHelper = ItemTouchHelper(_itemTouchHelperCallback)
itemTouchHelper.attachToRecyclerView(this)
```

在代码部分不是很难，难点其实是上面那个 onMoveHolder 方法。我一开始思考的是让用户在每次拖动时都处理，也就是真正的移动数据，但是这样的话，就会导致后台处理可能跟不上，导致数据错乱，所以我最后的实现是在拖动结束后，再去处理数据，这样就不会出现数据错乱的问题了。

下面是 onMoveHolder 的实现

```kotlin
// Only move in cache, not in tree
fun onMoveHolder(
    viewHolder: RecyclerView.ViewHolder,
    target: RecyclerView.ViewHolder
): Boolean {
    val srcNode = getItem(viewHolder.adapterPosition)
    var targetNode = getItem(max(0, target.adapterPosition - 1))

    if (targetNode.depth == 0) {
        targetNode = tree.getParentNode(targetNode) ?: targetNode
    }

    if (targetNode.path.startsWith(srcNode.path) && srcNode.depth < targetNode.depth) {
        return false
    }

    if (srcNode.path == targetNode.path) {
        targetNode = this@TreeView._adapter.getItem(target.adapterPosition)
    }

    srcNode.depth = if (targetNode.isChild) {
        targetNode.depth + 1
    } else {
        targetNode.depth
    }

    val currentList = currentList.toMutableList()

    Collections.swap(currentList, viewHolder.adapterPosition, target.adapterPosition)

    submitList(currentList)

    return true
}

```

这里就是主要能实现拖动效果的代码了，这里我只是在缓存里面对两个节点直接做了交换，然后再提交给 RecyclerView，这样就能实现拖动效果了。

我也对原始 node 的 depth 提前做了处理，这样就不会出现拖动时，节点的 depth 没有变化的问题了。

当然目前都是在 adapter 的数据处理，实际上没有真正发出给 tree。

### 2. 后台数据更新

数据更新这一块我打算在每次 move 时候存储起始节点和目标节点，然后在拖动结束后，再去真正的更新数据。

上面的代码已经有了，这里就不再重复了。

更新数据是调用的 `AbstractTree.moveNode` 方法，然后再去调用 `TreeNodeGenerator` 的 `moveNode` 方法，这里我就不再贴代码了，有兴趣的可以去看看。

这里贴一下我处理本地数据的实现：

```kotlin
override suspend fun moveNode(
    srcNode: TreeNode<DataSource<T>>,
    targetNode: TreeNode<DataSource<T>>,
    tree: AbstractTree<DataSource<T>>
): Boolean {

    if (targetNode.path.startsWith(srcNode.path) && srcNode.depth < targetNode.depth) {
        return false
    }

    val targetData = targetNode.requireData()
    val targetDataParent = targetData.parent
    val srcData = srcNode.requireData()
    val srcDataParent = srcData.parent


    val targetDataSource = if (targetData is MultipleDataSourceSupport<*>) {
        targetData as MultipleDataSourceSupport<T>
    } else {
        (targetDataParent as MultipleDataSourceSupport<T>)
    }

    val srcDataParentDataSource =
        srcDataParent as MultipleDataSourceSupport<T>

    srcDataParentDataSource.remove(srcData)

    targetDataSource.add(srcData)

    srcData.parent = if (targetData is MultipleDataSourceSupport<*>) {
        targetData
    } else {
        targetDataParent
    }


    return true
}
```

这是默认的 `DataSource` 里的处理，直接把目标节点的数据添加到源节点的数据里，然后再把源节点从源节点的父节点的数据里移除。

注意到我上面有加了一个 `if (targetNode.path.startsWith(srcNode.path) && srcNode.depth < targetNode.depth) { return false }`，这是为了防止用户把节点拖到自己的子节点下面，这样会导致数据错乱。(实际上真实文件系统也不会让你这么做)

### 3. UI 视觉效果

上面 1 那里的代码其实有一些就是在调用我接下来的接口，这些接口是给用户用于处理拖动时的视觉效果的

```kotlin

/**
 * Binder for TreeView and nodes.
 *
 * TreeView calls this class to get the generated itemView and bind the node data to the itemView
 *
 * @see [TreeView.binder]
 */
abstract class TreeViewBinder<T : Any> : DiffUtil.ItemCallback<TreeNode<T>>() {

    /**
     * like [ItemTouchHelper.Callback.clearView]
     *
     * Called when the view is released after dragging.
     *
     * You can override this method to do some operations on the view, such as set background color, etc.
     *
     * And you need to call [AbstractTree.moveNode], otherwise the node will not be moved.
     *
     *
     * @see [ItemTouchHelper.Callback.clearView]
     */
    open fun onMovedView(
        srcNode: TreeNode<T>,
        targetNode: TreeNode<T>? = null,
        holder: RecyclerView.ViewHolder
    ) {
    }

    /**
     * like [ItemTouchHelper.Callback.onSelectedChanged]
     *
     * Called when the view is selected after dragging.
     *
     * You can override this method to do some operations on the view, such as set background color, etc.
     */
    open fun onMoveView(
        srcHolder: RecyclerView.ViewHolder,
        srcNode: TreeNode<T>,
        targetHolder: RecyclerView.ViewHolder? = null,
        targetNode: TreeNode<T>? = null,
    ): Boolean {
        return true
    }
}

```

上面的 `onMoveView` 在拖动的时候调用，可以用来处理拖动时的视觉效果，比如改变背景颜色等。

`onMovedView` 在拖动结束后调用，可以用来处理拖动结束后的视觉效果，比如恢复背景颜色。

在我 demo 里的实现是调节 alpha 值，可以说是一个简单的实现了。

```kotlin
class ViewBinder : TreeViewBinder<DataSource<String>>(){
    override fun onMoveView(
        srcHolder: RecyclerView.ViewHolder,
        srcNode: TreeNode<DataSource<String>>,
        targetHolder: RecyclerView.ViewHolder?,
        targetNode: TreeNode<DataSource<String>>?
    ): Boolean {
        applyDepth(srcHolder as TreeView.ViewHolder, srcNode)

        srcHolder.itemView.alpha = 0.7f

        return true
    }

    override fun onMovedView(
        srcNode: TreeNode<DataSource<String>>,
        targetNode: TreeNode<DataSource<String>>?,
        holder: RecyclerView.ViewHolder
    ) {
        holder.itemView.alpha = 1f
    }
}
```

## 总结

实现出来的拖动效果还是不错的，当然也是遇到了一些问题，比如拖动时，节点的 depth 没有变化，导致拖动结束后，节点的 depth 也没有变化，这样就会导致节点的显示错乱，这个问题我是在上面的 onMoveHolder 里面处理的。

整个步骤很简单，感谢 [ItemTouchHelper](https://developer.android.com/reference/android/support/v7/widget/helper/ItemTouchHelper) 的帮助，让我可以很方便的实现拖动效果。

这里也推广一下我的库，上面的代码实现都在库里：[TreeView](https://github.com/dingyi222666/TreeView)

果然还是写 Android 的感觉舒服~
