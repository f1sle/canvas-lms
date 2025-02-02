/*
 * Copyright (C) 2020 - present Instructure, Inc.
 *
 * This file is part of Canvas.
 *
 * Canvas is free software: you can redistribute it and/or modify it under
 * the terms of the GNU Affero General Public License as published by the Free
 * Software Foundation, version 3 of the License.
 *
 * Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
 * A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
 * details.
 *
 * You should have received a copy of the GNU Affero General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */

import React, {useState} from 'react'
import {PresentationContent} from '@instructure/ui-a11y'
import {Billboard} from '@instructure/ui-billboard'
import {Flex} from '@instructure/ui-flex'
import {Spinner} from '@instructure/ui-spinner'
import {Text} from '@instructure/ui-text'
import {View} from '@instructure/ui-view'
import I18n from 'i18n!OutcomeManagement'
import SVGWrapper from 'jsx/shared/SVGWrapper'
import ManageOutcomesView from './ManageOutcomesView'
import ManageOutcomesFooter from './ManageOutcomesFooter'
import useSearch from 'jsx/shared/hooks/useSearch'
import TreeBrowser from './TreeBrowser'
import {useManageOutcomes} from 'jsx/outcomes/shared/treeBrowser'
import useCanvasContext from 'jsx/outcomes/shared/hooks/useCanvasContext'
import useModal from '../../shared/hooks/useModal'
import useGroupDetail from '../shared/hooks/useGroupDetail'
import MoveModal from './MoveModal'
import GroupRemoveModal from './GroupRemoveModal'
import OutcomeRemoveModal from './OutcomeRemoveModal'
import useModalWithData from 'jsx/outcomes/shared/hooks/useModalWithData'

const NoOutcomesBillboard = () => {
  const {contextType} = useCanvasContext()
  const isCourse = contextType === 'Course'

  return (
    <div className="management-panel" data-testid="outcomeManagementPanel">
      <Billboard
        size="large"
        headingLevel="h3"
        heading={
          isCourse
            ? I18n.t('Outcomes have not been added to this course yet.')
            : I18n.t('Outcomes have not been added to this account yet.')
        }
        message={
          isCourse
            ? I18n.t('Get started by finding, importing or creating your course outcomes.')
            : I18n.t('Get started by finding, importing or creating your account outcomes.')
        }
        hero={
          <div>
            <PresentationContent>
              <SVGWrapper url="/images/magnifying_glass.svg" />
            </PresentationContent>
          </div>
        }
      />
    </div>
  )
}

const OutcomeManagementPanel = () => {
  const {contextType} = useCanvasContext()
  const [searchString, onSearchChangeHandler, onSearchClearHandler] = useSearch()
  const [selectedOutcomes, setSelectedOutcomes] = useState({})
  const selected = Object.keys(selectedOutcomes).length
  const onSelectOutcomesHandler = id =>
    setSelectedOutcomes(prevState => {
      const updatedState = {...prevState}
      prevState[id] ? delete updatedState[id] : (updatedState[id] = true)
      return updatedState
    })
  const noop = () => {}
  const {
    error,
    isLoading,
    collections,
    queryCollections,
    rootId,
    selectedGroupId
  } = useManageOutcomes()
  const {loading, group, loadMore} = useGroupDetail(selectedGroupId)

  const [isMoveGroupModalOpen, openMoveGroupModal, closeMoveGroupModal] = useModal()
  const [isGroupRemoveModalOpen, openGroupRemoveModal, closeGroupRemoveModal] = useModal()
  const [
    outcomeRemoveModalData,
    openOutcomeRemoveModal,
    closeOutcomeRemoveModal
  ] = useModalWithData()
  const groupMenuHandler = (_, action) => {
    if (action === 'move') {
      openMoveGroupModal()
    } else if (action === 'remove') {
      openGroupRemoveModal()
    }
  }
  const outcomeMenuHandler = (id, action) => {
    if (action === 'remove') openOutcomeRemoveModal({id})
  }

  if (isLoading) {
    return (
      <div style={{textAlign: 'center'}}>
        <Spinner renderTitle={I18n.t('Loading')} size="large" />
      </div>
    )
  }

  if (error) {
    return (
      <Text color="danger">
        {contextType === 'Course'
          ? I18n.t('An error occurred while loading course outcomes: %{error}', {error})
          : I18n.t('An error occurred while loading account outcomes: %{error}', {error})}
      </Text>
    )
  }

  // Currently we're checking the presence of outcomes by checking the presence of folders
  // we need to implement the correct behavior later
  // https://gerrit.instructure.com/c/canvas-lms/+/255898/8/app/jsx/outcomes/Management/index.js#235
  const hasOutcomes = Object.keys(collections).length > 1

  return (
    <div className="management-panel" data-testid="outcomeManagementPanel">
      {!hasOutcomes ? (
        <NoOutcomesBillboard />
      ) : (
        <>
          <Flex>
            <Flex.Item
              width="33%"
              display="inline-block"
              position="relative"
              height="60vh"
              as="div"
            >
              <View as="div" padding="small none none x-small">
                <Text size="large" weight="light" fontStyle="normal">
                  {I18n.t('Outcome Groups')}
                </Text>
                <TreeBrowser
                  onCollectionToggle={queryCollections}
                  collections={collections}
                  rootId={rootId}
                />
              </View>
            </Flex.Item>
            <Flex.Item
              width="1%"
              display="inline-block"
              position="relative"
              padding="small none large none"
              margin="small none none none"
              borderWidth="none small none none"
              height="60vh"
              as="div"
            />
            <Flex.Item
              as="div"
              width="66%"
              display="inline-block"
              position="relative"
              height="60vh"
              overflowY="visible"
              overflowX="auto"
            >
              <View as="div" padding="x-small none none x-small">
                {selectedGroupId && (
                  <ManageOutcomesView
                    key={selectedGroupId}
                    outcomeGroup={group}
                    loading={loading}
                    selectedOutcomes={selectedOutcomes}
                    searchString={searchString}
                    onSelectOutcomesHandler={onSelectOutcomesHandler}
                    onOutcomeGroupMenuHandler={groupMenuHandler}
                    onOutcomeMenuHandler={outcomeMenuHandler}
                    onSearchChangeHandler={onSearchChangeHandler}
                    onSearchClearHandler={onSearchClearHandler}
                    loadMore={loadMore}
                  />
                )}
              </View>
            </Flex.Item>
          </Flex>
          <hr />
          {selectedGroupId && (
            <ManageOutcomesFooter selected={selected} onRemoveHandler={noop} onMoveHandler={noop} />
          )}
          <MoveModal
            title={group ? group.title : ''}
            type="group"
            isOpen={isMoveGroupModalOpen}
            onCloseHandler={closeMoveGroupModal}
          />
          {selectedGroupId && (
            <GroupRemoveModal
              groupId={selectedGroupId}
              isOpen={isGroupRemoveModalOpen}
              onCloseHandler={closeGroupRemoveModal}
            />
          )}
          {selectedGroupId && outcomeRemoveModalData?.id && (
            <OutcomeRemoveModal
              groupId={selectedGroupId}
              outcomeId={outcomeRemoveModalData?.id}
              isOpen={outcomeRemoveModalData?.open}
              onCloseHandler={closeOutcomeRemoveModal}
            />
          )}
        </>
      )}
    </div>
  )
}

export default OutcomeManagementPanel
